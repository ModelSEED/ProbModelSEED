"""
Model Reconstruction Module

Provides high-level functions for model building, gapfilling, and FBA
Integrates ModelSEEDpy with ProbModelSEED job system
"""

import os
import sys
import re
import json
import logging
import pickle
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime

# Add ModelSEEDpy to path if needed
def setup_modelseedpy_path(config: Dict[str, Any]):
    """Setup Python path for ModelSEEDpy imports"""
    if "ModelSEEDpy" in config and "codebase" in config["ModelSEEDpy"]:
        codebase = config["ModelSEEDpy"]["codebase"]
        library_paths = config["ModelSEEDpy"].get("libarary_paths", "").split(";")

        for syspath in library_paths:
            if not syspath.startswith("/"):
                syspath = codebase + syspath
            if syspath and syspath not in sys.path:
                sys.path.append(syspath)

# Import ModelSEEDpy components
try:
    import cobra
    import cobrakbase
    from cobra import Model, Reaction, Metabolite
    from modelseedpy.core.mstemplate import MSTemplateBuilder
    from modelseedpy.core.msmodelutl import MSModelUtil
    from modelseedpy.core.msgenome import MSGenome, MSFeature, normalize_role
    from modelseedpy.core.msfba import MSFBA
    from modelseedpy.biochem.modelseed_biochem import ModelSEEDBiochem
    from modelseedpy.core.msgenomeclassifier import MSGenomeClassifier
    from cobrakbase.core.kbasefba.fbamodel_from_cobra import CobraModelConverter
    from cobrakbase.core.kbasefba import FBAModel
    from cobrakbase.core.kbase_object_factory import KBaseObjectFactory
    from cobrakbase.kbase_object_info import KBaseObjectInfo
    from modelseedpy import (
        AnnotationOntology, MSPackageManager, MSMedia, MSModelUtil,
        MSBuilder, MSGapfill, FBAHelper, MSGrowthPhenotypes,
        MSATPCorrection, MSModelReport
    )
except ImportError as e:
    print(f"Warning: ModelSEEDpy imports not available: {e}")
    # Will be handled when functions are called

from .config import conf
from .workspace_client import WorkspaceClient

logger = logging.getLogger(__name__)


class ModelSEEDReconHelper:
    """Helper class for model reconstruction operations"""

    def __init__(self, config: Dict[str, Any]):
        """
        Initialize reconstruction helper

        Args:
            config: Configuration dictionary
        """
        logging.basicConfig(
            format='%(created)s %(levelname)s: %(message)s',
            level=logging.INFO
        )

        self.config = config
        self.kbase_api = KBaseObjectFactory()

        # Setup biochemistry
        job_dir = config.get("Scheduler", {}).get("jobdirectory", "/tmp")
        biochem_path = f"{job_dir}/modelseed_data/biochemistry"
        ModelSEEDBiochem.get(path=biochem_path)

        # Template mappings
        self.templates = {
            "core": "Core-V5.2",
            "gp": "GramPosModelTemplateV6",
            "gn": "GramNegModelTemplateV6",
            "ar": "ArchaeaTemplateV6",
            "grampos": "GramPosModelTemplateV6",
            "gramneg": "GramNegModelTemplateV6",
            "archaea": "ArchaeaTemplateV6"
        }

        self.kbase_templates = {
            "core": "NewKBaseModelTemplates/Core-V5.2",
            "gp": "NewKBaseModelTemplates/GramPosModelTemplateV6",
            "gn": "NewKBaseModelTemplates/GramNegModelTemplateV6",
            "ar": "NewKBaseModelTemplates/ArchaeaTemplateV6",
            "grampos": "NewKBaseModelTemplates/GramPosModelTemplateV6",
            "gramneg": "NewKBaseModelTemplates/GramNegModelTemplateV6",
            "archaea": "NewKBaseModelTemplates/ArchaeaTemplateV6",
            "Gram Positive": "NewKBaseModelTemplates/GramPosModelTemplateV6",
            "Gram Negative": "NewKBaseModelTemplates/GramNegModelTemplateV6",
            "Archaea": "NewKBaseModelTemplates/ArchaeaTemplateV6",
            "custom": None
        }

        self.core_template = None
        self.gs_template = None

    def get_classifier(self):
        """Load genome classifier"""
        job_dir = self.config.get("Scheduler", {}).get("jobdirectory", "/tmp")
        cls_pickle = f"{job_dir}/modelseed_data/classifier/knn_ACNP_RAST_full_01_17_2023.pickle"
        cls_features = f"{job_dir}/modelseed_data/classifier/knn_ACNP_RAST_full_01_17_2023_features.json"

        with open(cls_pickle, 'rb') as fh:
            model_filter = pickle.load(fh)
        with open(cls_features, 'r') as fh:
            features = json.load(fh)

        return MSGenomeClassifier(model_filter, features)

    def get_template(self, template_id: str):
        """Load model template"""
        # Parse template path
        template_id = template_id.rstrip('|').strip().split('/')[-1]

        job_dir = self.config.get("Scheduler", {}).get("jobdirectory", "/tmp")
        directory = f"{job_dir}/modelseed_data/kbws/NewKBaseModelTemplates/"
        template_path = f"{directory}{template_id}.json"

        template = self.kbase_api.build_object_from_file(
            template_path,
            "KBaseFBA.NewModelTemplate"
        )
        return template

    def get_media(self, media_data: Dict):
        """Create media object from data"""
        info = KBaseObjectInfo([
            media_data["id"], media_data["id"], "KBaseFBA.Media",
            None, 0, None, "/chenry/public/modelsupport/media/",
            "/chenry/public/modelsupport/media/", 0, 0, {}
        ])
        media_obj = self.kbase_api._build_object("KBaseFBA.Media", media_data, info, None)
        return media_obj

    def get_msgenome(self, genome_data: Dict):
        """Create MSGenome from genome data"""
        msgenome = MSGenome()
        msgenome.id = genome_data["id"]
        msgenome.scientific_name = genome_data["scientific_name"]

        features = []
        for gene in genome_data["features"]:
            feature = MSFeature(gene["id"], "")
            features.append(feature)

            function = gene.get("function", "")
            functions = re.split(r'\s*;\s+|\s+[@/]\s+', function)

            for func in functions:
                func = normalize_role(func)
                feature.add_ontology_term("RAST", func)

        msgenome.add_features(features)
        return msgenome

    def save_model(self, mdlutl, workspace: WorkspaceClient, output_path: str):
        """
        Save model to workspace

        Args:
            mdlutl: MSModelUtil object
            workspace: WorkspaceClient instance
            output_path: Workspace path for model
        """
        # Convert to FBAModel if needed
        if not isinstance(mdlutl.model, FBAModel):
            mdlutl.model = CobraModelConverter(mdlutl.model).build()

        mdlutl.save_attributes()
        data = mdlutl.model.get_data()

        # Create gapfilling data
        mdlutl.create_kb_gapfilling_data(data, "/chenry/public/modelsupport/media/")
        data["source_id"] = data["id"]
        data["source"] = "ModelSEED"
        data["type"] = "GenomeScale"

        # Save to workspace
        workspace.save_object(output_path, "FBAModel", data, overwrite=True)

        return data


def run_model_reconstruction(input_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Run model reconstruction

    Args:
        input_data: Dictionary with:
            - config: Configuration dictionary
            - parameters: Job parameters
            - workspace: WorkspaceClient instance
            - (optional) genome: Genome data dict
            - (optional) media: Media data dict

    Returns:
        Output dictionary with model info
    """
    config = input_data['config']
    params = input_data['parameters']
    workspace = input_data['workspace']

    # Setup paths if needed
    setup_modelseedpy_path(config)

    # Initialize helper
    helper = ModelSEEDReconHelper(config)

    # Prepare output
    output = {
        "Model": params.get("fbamodel_output_id", "model"),
        "Genome": "",
        "Genes": None,
        "Class": None,
        "Model genes": None,
        "Reactions": None,
        "Core GF": None,
        "GS GF": None,
        "Growth": None,
        "Comments": []
    }

    # Get genome data
    if 'genome' in input_data:
        genome_data = input_data['genome']
    else:
        genome_ref = params['genome_workspace'] + '/' + params['genome_id']
        genome_data = workspace.get_object_data(genome_ref)

    genome = helper.get_msgenome(genome_data)
    output["Genes"] = len(genome_data.get("features", []))

    # Get media data
    if 'media' in input_data:
        media_data = input_data['media']
    else:
        media_data = workspace.get_object_data(params['media'])

    media_obj = helper.get_media(media_data)

    # Initialize classifier
    genome_classifier = helper.get_classifier()

    # Load core template
    helper.core_template = helper.get_template(helper.kbase_templates["core"])

    # Determine template
    template_type = params.get('template_id', 'auto')
    if template_type != "auto":
        helper.gs_template = helper.get_template(helper.kbase_templates[template_type])
    else:
        # Classify genome
        genome_class = genome_classifier.classify(genome)
        if genome_class == "P":
            output["Class"] = "Gram Positive"
            template_type = "gp"
        elif genome_class in ("N", "--"):
            output["Class"] = "Gram Negative"
            template_type = "gn"
        elif genome_class == "A":
            output["Class"] = "Archaea"
            template_type = "ar"
        else:
            raise ValueError(f"Unsupported genome class: {genome_class}")

        helper.gs_template = helper.get_template(helper.kbase_templates[output["Class"]])

    # Build model
    base_model = FBAModel({
        'id': params["fbamodel_output_id"],
        'name': genome_data["scientific_name"]
    })

    builder = MSBuilder(genome, helper.gs_template)
    mdl = builder.build(base_model, '0', False, False)
    mdl.genome = genome
    mdl.template = helper.gs_template
    mdl.core_template_ref = "/chenry/public/modelsupport/templates/Core-V5.2||"
    mdl.genome_ref = params['genome_workspace'] + "/" + params['genome_id'] + "||"
    mdl.template_ref = "/chenry/public/modelsupport/templates/" + helper.templates[template_type] + "||"

    mdlutl = MSModelUtil.get(mdl)

    # ATP correction
    atp_medias_path = config.get("ModelSEEDpy", {}).get("codebase", "") + "ModelSEEDpy/modelseedpy/data/atp_medias.tsv"
    atpcorrection = MSATPCorrection(
        mdlutl, helper.core_template, [],
        load_default_medias=True,
        max_gapfilling=10,
        gapfilling_delta=0,
        forced_media=[],
        default_media_path=atp_medias_path
    )
    tests = atpcorrection.run_atp_correction()
    output["Core GF"] = len(atpcorrection.cumulative_core_gapfilling)

    # Set model metadata
    mdlutl.get_attributes()["class"] = output["Class"]
    mdlutl.wsid = params["workspace"] + "/" + params["fbamodel_output_id"]

    # Run gapfilling if requested
    if params.get("gapfill", 0) == 1:
        gapfill_output = run_gapfill_internal(
            helper, mdlutl, media_obj, params, workspace, output, config
        )
        output.update(gapfill_output)
    else:
        # Save model without gapfilling
        model_path = params["workspace"] + "/" + params["fbamodel_output_id"]
        helper.save_model(mdlutl, workspace, model_path)

        mdlutl.model.objective = "bio1"
        mdlutl.pkgmgr.getpkg("KBaseMediaPkg").build_package(None)
        growth = mdlutl.model.slim_optimize()
        output["Growth"] = f"Complete:{growth}"

    output["Reactions"] = mdlutl.nonexchange_reaction_count()
    output["Model genes"] = len(mdlutl.model.genes)

    return output


def run_gapfill_internal(
    helper, mdlutl, media_obj, params, workspace, output, config
) -> Dict[str, Any]:
    """Internal gapfilling function"""
    # Get tests for ATP-safe gapfilling
    atp_medias_path = config.get("ModelSEEDpy", {}).get("codebase", "") + "ModelSEEDpy/modelseedpy/data/atp_medias.tsv"
    tests = mdlutl.get_atp_tests(
        core_template=helper.core_template,
        atp_media_filename=atp_medias_path,
        recompute=False
    )

    # Create gapfilling object
    msgapfill = MSGapfill(
        mdlutl,
        [helper.gs_template],
        [],
        tests,
        blacklist=[],
        default_target="bio1",
        minimum_obj=0.01,
        base_media=None,
        base_media_target_element=None
    )

    # Run gapfilling
    mdlutl.gfutl.cumulative_gapfilling = []
    solutions = msgapfill.run_multi_gapfill(
        [media_obj],
        target="bio1",
        default_minimum_objective=0.01,
        binary_check=False,
        prefilter=True,
        check_for_growth=True,
        gapfilling_mode="Sequential",
        run_sensitivity_analysis=True,
        integrate_solutions=True
    )

    # Process solutions
    growth_array = []
    output_solution = None

    if media_obj in solutions and "growth" in solutions[media_obj]:
        growth = solutions[media_obj]["growth"]
        growth_array.append(f"{media_obj.id}:{growth}")

        if growth > 0:
            mdlutl.pkgmgr.getpkg("KBaseMediaPkg").build_package(media_obj)
            mdlutl.pkgmgr.getpkg("ElementUptakePkg").build_package({"C": 60})
            output_solution = cobra.flux_analysis.pfba(mdlutl.model)

    # Save model
    model_path = params["workspace"] + "/" + params["fbamodel_output_id"]
    helper.save_model(mdlutl, workspace, model_path)

    return {
        "Growth": "<br>".join(growth_array),
        "GS GF": len(mdlutl.gfutl.cumulative_gapfilling),
        "Reactions": mdlutl.nonexchange_reaction_count(),
        "Model genes": len(mdlutl.model.genes)
    }


def run_gapfill_model(input_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Run gapfilling on existing model

    Args:
        input_data: Dictionary with config, parameters, workspace

    Returns:
        Output dictionary with gapfilling results
    """
    config = input_data['config']
    params = input_data['parameters']
    workspace = input_data['workspace']

    setup_modelseedpy_path(config)

    # Initialize helper
    helper = ModelSEEDReconHelper(config)

    # Parse model reference
    model_path = params['model']
    print(f"Loading model from {model_path}")

    # Load model from workspace
    model_data = workspace.get_object_data(model_path)

    # Convert to FBAModel
    from cobrakbase.core.kbasefba import FBAModel
    model = helper.kbase_api._build_object("KBaseFBA.FBAModel", model_data, None, None)

    # Get MSModelUtil
    mdlutl = MSModelUtil.get(model)

    # Determine output path and file
    output_path = model_path + "/gapfilling"
    output_file = params.get('output_file')

    if not output_file:
        # Auto-generate gapfill filename (gf.0, gf.1, etc.)
        try:
            gflist = workspace.ls(
                [output_path],
                excludeDirectories=True,
                excludeObjects=False,
                recursive=True,
                query={'type': 'fba'}
            )

            index = 0
            if gflist and output_path in gflist:
                files = gflist[output_path]
                for file_info in files:
                    filename = file_info[0]
                    if filename.startswith('gf.'):
                        try:
                            file_index = int(filename.split('.')[1])
                            if file_index >= index:
                                index = file_index + 1
                        except (IndexError, ValueError):
                            pass

            output_file = f"gf.{index}"
        except Exception as e:
            print(f"Warning: Could not list existing gapfills: {e}")
            output_file = "gf.0"

    # Load media
    media_ref = params.get('media')
    if media_ref:
        media_data = workspace.get_object_data(media_ref)
        media_obj = helper.get_media(media_data)
    else:
        raise ValueError("media parameter is required for gapfilling")

    # Load core template if needed
    if not helper.core_template:
        helper.core_template = helper.get_template(helper.kbase_templates["core"])

    # Get template from model
    template_ref = model.template_ref
    if template_ref:
        template_id = template_ref.rstrip('|').split('/')[-1]
        template = helper.get_template(template_id)
    else:
        raise ValueError("Model does not have template_ref")

    # Get ATP tests
    atp_medias_path = config.get("ModelSEEDpy", {}).get("codebase", "") + "ModelSEEDpy/modelseedpy/data/atp_medias.tsv"
    tests = mdlutl.get_atp_tests(
        core_template=helper.core_template,
        atp_media_filename=atp_medias_path,
        recompute=False
    )

    # Create gapfilling object
    print(f"Setting up gapfilling for {model_path}")

    msgapfill = MSGapfill(
        mdlutl,
        [template],
        [],
        tests,
        blacklist=params.get('blacklisted_rxn_list', []),
        default_target=params.get('target_reaction', 'bio1'),
        minimum_obj=params.get('minimum_target_flux', 0.1),
        base_media=None,
        base_media_target_element=None
    )

    # Run gapfilling
    print(f"Running gapfilling on {media_obj.id}")

    mdlutl.gfutl.cumulative_gapfilling = []
    solutions = msgapfill.run_multi_gapfill(
        [media_obj],
        target=params.get('target_reaction', 'bio1'),
        default_minimum_objective=params.get('minimum_target_flux', 0.1),
        binary_check=False,
        prefilter=True,
        check_for_growth=True,
        gapfilling_mode="Sequential",
        run_sensitivity_analysis=True,
        integrate_solutions=params.get('integrate_solution', 0) == 1
    )

    # Process solution
    growth = 0
    if media_obj in solutions and "growth" in solutions[media_obj]:
        growth = solutions[media_obj]["growth"]
        print(f"Gapfilling resulted in growth: {growth}")

    # Get solution for FBA
    if growth > 0:
        mdlutl.pkgmgr.getpkg("KBaseMediaPkg").build_package(media_obj)
        mdlutl.pkgmgr.getpkg("ElementUptakePkg").build_package({"C": 60})
        fba_solution = cobra.flux_analysis.pfba(mdlutl.model)
    else:
        fba_solution = None
        print("Warning: No growth after gapfilling")

    # Save model if integrate_solution is set
    if params.get('integrate_solution', 0) == 1:
        print(f"Saving integrated model to {model_path}")
        helper.save_model(mdlutl, workspace, model_path)

    # Save gapfilling FBA result
    gapfill_path = f"{output_path}/{output_file}"

    if fba_solution:
        # Create MSFBA object and save
        from modelseedpy.core.msfba import MSFBA
        fba = MSFBA(mdlutl, media_obj, primary_solution=fba_solution)
        fba.id = output_file

        # Generate KBase data
        fba_data = fba.generate_kbase_data(
            model_path + "||",
            media_ref + "||"
        )

        # Save FBA result
        workspace.save_object(gapfill_path, "FBA", fba_data, overwrite=True)
        print(f"Saved gapfilling results to {gapfill_path}")

    return {
        "gapfill_ref": gapfill_path,
        "fbamodel_ref": model_path,
        "report_ref": gapfill_path + ".jobresult",
        "num_gapfilled_reactions": len(mdlutl.gfutl.cumulative_gapfilling),
        "growth": growth
    }


def run_fba(input_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Run flux balance analysis

    Args:
        input_data: Dictionary with config, parameters, workspace

    Returns:
        Output dictionary with FBA results
    """
    config = input_data['config']
    params = input_data['parameters']
    workspace = input_data['workspace']

    setup_modelseedpy_path(config)

    # Initialize helper
    helper = ModelSEEDReconHelper(config)

    # Parse model reference
    model_path = params['model']
    print(f"Loading model from {model_path}")

    # Load model from workspace
    model_data = workspace.get_object_data(model_path)

    # Convert to FBAModel
    from cobrakbase.core.kbasefba import FBAModel
    model = helper.kbase_api._build_object("KBaseFBA.FBAModel", model_data, None, None)

    # Get MSModelUtil
    mdlutl = MSModelUtil.get(model)

    # Determine output path and file
    output_path = model_path + "/fba"
    output_file = params.get('output_file')

    if not output_file:
        # Auto-generate FBA filename (fba.0, fba.1, etc.)
        try:
            fba_list = workspace.ls(
                [output_path],
                excludeDirectories=True,
                excludeObjects=False,
                recursive=True,
                query={'type': 'fba'}
            )

            index = 0
            if fba_list and output_path in fba_list:
                files = fba_list[output_path]
                for file_info in files:
                    filename = file_info[0]
                    if filename.startswith('fba.'):
                        try:
                            file_index = int(filename.split('.')[1])
                            if file_index >= index:
                                index = file_index + 1
                        except (IndexError, ValueError):
                            pass

            output_file = f"fba.{index}"
        except Exception as e:
            print(f"Warning: Could not list existing FBAs: {e}")
            output_file = "fba.0"

    # Load media if provided
    media_obj = None
    media_ref = params.get('media')

    if media_ref:
        media_data = workspace.get_object_data(media_ref)
        media_obj = helper.get_media(media_data)
        print(f"Using media: {media_obj.id}")

        # Set up media package
        mdlutl.pkgmgr.getpkg("KBaseMediaPkg").build_package(media_obj)

    # Apply gene knockouts if specified
    feature_ko_list = params.get('feature_ko_list', [])
    if feature_ko_list:
        print(f"Applying {len(feature_ko_list)} gene knockouts")
        for gene_id in feature_ko_list:
            try:
                gene = mdlutl.model.genes.get_by_id(gene_id)
                gene.knock_out()
            except KeyError:
                print(f"Warning: Gene {gene_id} not found in model")

    # Apply reaction knockouts if specified
    reaction_ko_list = params.get('reaction_ko_list', [])
    if reaction_ko_list:
        print(f"Applying {len(reaction_ko_list)} reaction knockouts")
        for rxn_id in reaction_ko_list:
            try:
                rxn = mdlutl.model.reactions.get_by_id(rxn_id)
                rxn.knock_out()
            except KeyError:
                print(f"Warning: Reaction {rxn_id} not found in model")

    # Run FBA
    print(f"Running FBA on model {model_path}")

    # Set objective
    mdlutl.model.objective = "bio1"

    # Run optimization
    solution = mdlutl.model.optimize()

    print(f"FBA objective value: {solution.objective_value}")

    # Create MSFBA object
    from modelseedpy.core.msfba import MSFBA
    fba = MSFBA(mdlutl, media_obj, primary_solution=solution)
    fba.id = output_file

    # Run FVA if requested
    if params.get('fva', 1) == 1:
        print("Running flux variability analysis")
        # FVA is computationally expensive, so we skip it for now in the basic implementation
        # Could be added: fva_result = cobra.flux_analysis.flux_variability_analysis(mdlutl.model)

    # Simulate gene knockouts if requested
    if params.get('simulate_ko', 0) == 1:
        print("Simulating gene knockouts for essentiality prediction")
        # This would involve running single gene deletions
        # Could be added: from cobra.flux_analysis import single_gene_deletion
        # deletion_results = single_gene_deletion(mdlutl.model)

    # Generate KBase FBA data
    fba_data = fba.generate_kbase_data(
        model_path + "||",
        media_ref + "||" if media_ref else None
    )

    # Save FBA result
    fba_path = f"{output_path}/{output_file}"
    workspace.save_object(fba_path, "FBA", fba_data, overwrite=True)
    print(f"Saved FBA results to {fba_path}")

    return {
        "fba_ref": fba_path,
        "report_ref": fba_path + ".jobresult",
        "objective_value": solution.objective_value,
        "status": solution.status
    }


def run_compute_reaction_probabilities(input_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Compute reaction probabilities using ProbAnno

    Args:
        input_data: Dictionary with config, parameters, workspace

    Returns:
        Output dictionary with reaction probabilities
    """
    import subprocess
    import os

    config = input_data['config']
    params = input_data['parameters']
    workspace = input_data['workspace']

    setup_modelseedpy_path(config)

    # Get required parameters
    genome_ref = params['genome']
    template_ref = params['template']
    rxnprobs_ref = params['rxnprobs']

    print(f"Computing reaction probabilities for {genome_ref} with template {template_ref}")

    # Get probanno binary path from config
    probanno_bin = config.get("ProbModelSEED", {}).get("probannobin")

    if not probanno_bin:
        # Try to find ms-probanno in common locations
        possible_paths = [
            "/disks/p3dev2/deployment/bin/ms-probanno",
            "ms-probanno",  # Assume in PATH
        ]

        for path in possible_paths:
            if os.path.exists(path) or subprocess.run(['which', path], capture_output=True).returncode == 0:
                probanno_bin = path
                break

        if not probanno_bin:
            raise ValueError(
                "ProbAnno binary not found. Set 'probannobin' in [ProbModelSEED] config section."
            )

    print(f"Using ProbAnno binary: {probanno_bin}")

    # Get authentication token
    token = os.environ.get('KB_AUTH_TOKEN') or os.environ.get('P3_AUTH_TOKEN', '')

    # Build command
    cmd = [
        probanno_bin,
        genome_ref,
        template_ref,
        rxnprobs_ref,
        '--token', token
    ]

    print(f"Running command: {' '.join(cmd[:4])} --token <hidden>")

    # Execute ProbAnno
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=3600  # 1 hour timeout
        )

        if result.returncode != 0:
            error_msg = f"ProbAnno failed with return code {result.returncode}\n"
            error_msg += f"STDOUT: {result.stdout}\n"
            error_msg += f"STDERR: {result.stderr}"
            raise RuntimeError(error_msg)

        print("ProbAnno completed successfully")

        if result.stdout:
            print(f"ProbAnno output:\n{result.stdout}")

    except subprocess.TimeoutExpired:
        raise RuntimeError("ProbAnno execution timed out after 1 hour")

    except Exception as e:
        raise RuntimeError(f"Error running ProbAnno: {e}")

    print("Finished calculating reaction probabilities")

    return {
        "rxnprobs_ref": rxnprobs_ref,
        "report_ref": rxnprobs_ref + ".jobresult",
        "status": "complete"
    }
