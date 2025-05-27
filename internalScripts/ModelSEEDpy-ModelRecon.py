import os
from os.path import exists
import sys
import logging
import json
import argparse

# Parse command line arguments
parser = argparse.ArgumentParser(description='ModelSEED model reconstruction script')
parser.add_argument('filename', help='JSON file containing input data')
args = parser.parse_args()

# Read parameters from JSON file
with open(args.filename) as f:
    input = json.load(f)

codebase = input["config"]["ModelSEEDpy"]["codebase"]
syspaths = input["config"]["ModelSEEDpy"]["libarary_paths"].split(";")
for syspath in syspaths:
    if not syspath[0] == "/":
        syspath = codebase+syspath
    if not syspath in sys.path:
        sys.path.append(syspath)

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import re
import pandas as pd
from optlang.symbolics import Zero, add
import cobra
import cobrakbase
from cobra import Model, Reaction, Metabolite
from modelseedpy.core.mstemplate import MSTemplateBuilder
from modelseedpy.core.msmodelutl import MSModelUtil
from modelseedpy.core.msgenome import MSGenome, MSFeature, normalize_role
from modelseedpy.core.msfba import MSFBA
from modelseedpy.biochem.modelseed_biochem import ModelSEEDBiochem
from modelseedpy.biochem.modelseed_reaction import ModelSEEDReaction2
from modelseedpy.biochem.modelseed_compound import ModelSEEDCompound2
from modelseedpy.core.annotationontology import AnnotationOntology
from modelseedpy.core.msgrowthphenotypes import MSGrowthPhenotypes
from modelseedpy.core.msgenomeclassifier import MSGenomeClassifier
from cobrakbase.core.kbasefba.fbamodel_from_cobra import CobraModelConverter
from cobrakbase.core.kbasefba import FBAModel
from cobrakbase.core.kbase_object_factory import KBaseObjectFactory
from cobrakbase.kbase_object_info import KBaseObjectInfo
from modelseedpy import AnnotationOntology, MSPackageManager, MSMedia, MSModelUtil, MSBuilder, MSGapfill, FBAHelper, MSGrowthPhenotypes, MSModelUtil, MSATPCorrection,MSModelReport
from modelseedpy.helpers import get_template
import pickle

logger = logging.getLogger(__name__)

class ModelSEEDReconPATRIC:
    def __init__(self,config):
        logging.basicConfig(format='%(created)s %(levelname)s: %(message)s',
                            level=logging.INFO)
        self.kbase_api = KBaseObjectFactory()
        self.config = config
        ModelSEEDBiochem.get(path=self.config["Scheduler"]["jobdirectory"]+"/modelseed_data/biochemistry")
        #Loading default templates
        self.templates = {
            "core" : "Core-V5.2",
            "gp" : "GramPosModelTemplateV6",
            "gn" : "GramNegModelTemplateV6",
            "ar" : "ArchaeaTemplateV6",
            "grampos" : "GramPosModelTemplateV6",
            "gramneg" : "GramNegModelTemplateV6",
            "archaea" : "ArchaeaTemplateV6"
        }
        self.kbase_templates = {
            "core" : "NewKBaseModelTemplates/Core-V5.2",
            "gp" : "NewKBaseModelTemplates/GramPosModelTemplateV6",
            "gn" : "NewKBaseModelTemplates/GramNegModelTemplateV6",
            "ar" : "NewKBaseModelTemplates/ArchaeaTemplateV6",
            "grampos" : "NewKBaseModelTemplates/GramPosModelTemplateV6",
            "gramneg" : "NewKBaseModelTemplates/GramNegModelTemplateV6",
            "archaea" : "NewKBaseModelTemplates/ArchaeaTemplateV6",
            "Gram Positive" : "NewKBaseModelTemplates/GramPosModelTemplateV6",
            "Gram Negative" : "NewKBaseModelTemplates/GramNegModelTemplateV6",
            "Archaea" : "NewKBaseModelTemplates/ArchaeaTemplateV6",
            "custom": None
        }
        self.core_template = None
        self.util = None
        self.gs_template = None
        self.native_ontology = False
    
    #########GENERAL UTILITY FUNCTIONS#######################
    def validate_args(self,params,required,defaults):
        for item in required:
            if item not in params:
                raise ValueError('Required argument '+item+' is missing!')
        for key in defaults:
            if key not in params:
                params[key] = defaults[key]
        return params
    
    def print_json_debug_file(self,filename,data):
        filename = self.config["Scheduler"]["jobdirectory"]+"/jobs/"+self.config["Scheduler"]["jobid"]+"/debug.json"
        print("Printing debug file:",filename)
        with open(filename, 'w') as f:
            json.dump(data, f,indent=4,skipkeys=True)

    #################Classifier functions#####################
    def get_classifier(self):
        cls_pickle = self.config["Scheduler"]["jobdirectory"]+"/modelseed_data/classifier/knn_ACNP_RAST_full_01_17_2023.pickle"
        cls_features = self.config["Scheduler"]["jobdirectory"]+"/modelseed_data/classifier/knn_ACNP_RAST_full_01_17_2023_features.json"
        #cls_pickle = self.module_dir+"/data/knn_ACNP_RAST_filter.pickle"
        #cls_features = self.module_dir+"/data/knn_ACNP_RAST_filter_features.json"
        with open(cls_pickle, 'rb') as fh:
            model_filter = pickle.load(fh)
        with open(cls_features, 'r') as fh:
            features = json.load(fh)
        return MSGenomeClassifier(model_filter, features)
    
    #################Template functions#####################
    def get_gs_template(self,template_id,ws,core_template):
        gs_template = self.get_template(template_id,ws)
        for cpd in core_template.compcompounds:
            if cpd.id not in gs_template.compcompounds:
                gs_template.compcompounds.append(cpd)
        for rxn in core_template.reactions:
            if rxn.id in gs_template.reactions:
                gs_template.reactions._replace_on_id(rxn)
            else:
                gs_template.reactions.append(rxn)
        for rxn in gs_template.reactions:
            for met in rxn.metabolites:
                if met.id[0:8] in excluded_cpd:
                    gs_template.reactions.remove(rxn)
        return gs_template
    
    def parse_last_segment(self,path):
        # Remove trailing "||" if present
        cleaned = path.rstrip('|')
        # Split by "/" and return the last non-empty segment
        return cleaned.strip().split('/')[-1]

    def get_template(self,template_id):
        template_id = self.parse_last_segment(template_id)
        directory = self.config["Scheduler"]["jobdirectory"]+"/modelseed_data/kbws/NewKBaseModelTemplates/"
        directory = directory+template_id
        template = self.kbase_api.build_object_from_file(directory+".json", "KBaseFBA.NewModelTemplate")
        #template = self.kbase_api.get_object(template_id,ws)
        #info = self.kbase_api.get_object_info(template_id,ws)
        #template = MSTemplateBuilder.from_dict(template).build()
        return template

    def get_media(self,media_data):
        info = KBaseObjectInfo(
            [media_data["id"],media_data["id"],"KBaseFBA.Media",None,0,None,"/chenry/public/modelsupport/media/","/chenry/public/modelsupport/media/",0,0,{}],
        )
        media_obj = self.kbase_api._build_object("KBaseFBA.Media", media_data,info, None)
        return media_obj

    #################Save functions#####################
    def save_model(self,mdlutl):
        #Checking for zero flux reactions
        for rxn in mdlutl.model.reactions:
            if rxn.lower_bound == 0 and rxn.upper_bound == 0:
                print("Zero flux reaction: "+rxn.id)
        #Saving attributes and getting model data
        if not isinstance(mdlutl.model,FBAModel):
            mdlutl.model = CobraModelConverter(mdlutl.model).build()
        mdlutl.save_attributes()
        data = mdlutl.model.get_data()
        #Setting provenance and saving model using workspace API
        mdlutl.create_kb_gapfilling_data(data,"/chenry/public/modelsupport/media/")
        data["source_id"] = data["id"]
        data["source"] = "ModelSEED"
        data["type"] = "GenomeScale"
        filename = self.config["Scheduler"]["jobdirectory"]+"/jobs/"+self.config["Scheduler"]["jobid"]+"/output.json"
        with open(filename, 'w') as f:
            json.dump(data, f,indent=4,skipkeys=True)

    def save_solution_as_fba(self,fba_or_solution,mdlutl,media,fbaid,workspace=None,fbamodel_ref=None,other_solutions=None):
        if not isinstance(fba_or_solution,MSFBA):
            fba_or_solution = MSFBA(mdlutl,media,primary_solution=fba_or_solution)
        fba_or_solution.id = fbaid
        if other_solutions != None:
            for other_solution in other_solutions:
                fba_or_solution.add_secondary_solution(other_solution)
        data = fba_or_solution.generate_kbase_data(fbamodel_ref,media.info.reference)
        filename = self.config["Scheduler"]["jobdirectory"]+"/jobs/"+self.config["Scheduler"]["jobid"]+"/fba.json"
        with open(filename, 'w') as f:
            json.dump(data, f,indent=4,skipkeys=True)

    def convert_role_to_search_role(self,rolename):
        rolename = rolename.lower()
        rolename = re.sub(r'[\d\-]+\.[\d\-]+\.[\d\-]+\.[\d\-]+', '', rolename)
        rolename = re.sub(r'\s+', '', rolename)
        rolename = re.sub(r'#.*$', '', rolename)
        rolename = re.sub(r'\(ec\)', '', rolename)
        return rolename

    def get_msgenome(self,genome_data):
        msgenome = MSGenome()
        msgenome.id = genome_data["id"]
        msgenome.scientific_name = genome_data["scientific_name"]
        features = []
        for gene in genome_data["features"]:
            feature = MSFeature(gene["id"],"")
            features.append(feature)
            function = gene["function"]
            functions = re.split(r'\s*;\s+|\s+[@/]\s+', function)
            for func in functions:
                func = normalize_role(func)
                feature.add_ontology_term("RAST",func)
        msgenome.add_features(features)
        return msgenome

    #Primary functions
    def build_metabolic_models(self,input):
        #Initializing output
        current_output = {
            "Model":input["parameters"]["fbamodel_output_id"],"Genome":"","Genes":None,"Class":None,
            "Model genes":None,"Reactions":None,
            "Core GF":None,"GS GF":None,"Growth":None,"Comments":[]
        }
        #Creating media object from input
        media_obj = self.get_media(input["media"])
        #Initializing classifier
        genome_classifier = self.get_classifier()
        #Getting RAST annotated genome, which will be reannotated as needed
        genome = self.get_msgenome(input["genome"])
        current_output["Genes"] = len(input["genome"]["features"])
        #Preloading core and preselected template - note the default GS template is None because this signals for the classifier to be used to select the template
        self.gs_template = None
        self.core_template = self.get_template(self.kbase_templates["core"])
        template_type = input["parameters"]["template_id"]
        if template_type != "auto":
            self.gs_template = self.get_template(self.kbase_templates[input["parameters"]["template_id"]])
        else:
            current_output["Class"] = genome_classifier.classify(genome)
            if current_output["Class"] == "P":
                current_output["Class"] = "Gram Positive"
                template_type = "gp"
            elif current_output["Class"] == "N" or current_output["Class"] == "--":
                current_output["Class"] = "Gram Negative"
                template_type = "gn"
            elif current_output["Class"] == "A":
                current_output["Class"] = "Archaea"
                template_type = "ar"
            elif current_output["Class"] == "C":
                current_output["Class"] = "Cyanobacteria"
                template_type = "cyano"
                current_output["Comments"].append("Cyanobacteria not yet supported. Skipping genome.")
                result_table = result_table.append(current_output, ignore_index = True)
                return current_output
            else:
                current_output["Comments"].append("Unrecognized genome class "+current_output["Class"]+". Skipping genome.")
                result_table = result_table.append(current_output, ignore_index = True)
                return current_output
            self.gs_template = self.get_template(self.kbase_templates[current_output["Class"]])
        #Building model            
        base_model = FBAModel({'id':input["parameters"]["fbamodel_output_id"], 'name':input["genome"]["scientific_name"]})
        builder = MSBuilder(genome, self.gs_template)
        mdl = builder.build(base_model, '0', False, False)            
        mdl.genome = genome
        mdl.template = self.gs_template
        mdl.core_template_ref = "/chenry/public/modelsupport/templates/Core-V5.2||"
        mdl.genome_ref = input["parameters"]["genome_workspace"]+"/"+input["parameters"]["genome_id"]+"||"
        mdl.template_ref = "/chenry/public/modelsupport/templates/"+self.templates[template_type]+"||"
        current_output["Core GF"] = "NA" 
        mdlutl = MSModelUtil.get(mdl)
        genome_objs = {mdlutl:genome}
        atpcorrection = MSATPCorrection(mdlutl,self.core_template,[],load_default_medias=True,max_gapfilling=10,gapfilling_delta=0,forced_media=[],default_media_path=input["config"]["ModelSEEDpy"]["codebase"]+"ModelSEEDpy/modelseedpy/data/atp_medias.tsv")
        tests = atpcorrection.run_atp_correction()
        current_output["Core GF"] = len(atpcorrection.cumulative_core_gapfilling)
        #Setting the model ID so the model is saved with the correct name in KBase
        mdlutl.get_attributes()["class"] = current_output["Class"]
        mdlutl.wsid = input["parameters"]["workspace"]+"/"+input["parameters"]["fbamodel_output_id"]
        #Running gapfilling
        current_output["GS GF"] = "NA"
        if  input["parameters"]["gapfill"] == 1:
            self.gapfill_metabolic_models({
                "media_obj":media_obj,#
                "model_obj":mdlutl,#
                "atp_safe":True,#
                "default_objective":"bio1",#
                "output_data":current_output,#
                "template":self.gs_template,
                "internal_call":True,
                "config":input["config"],
                "parameters":input["parameters"]
            })
        else:
            self.save_model(mdlutl)
            mdlutl.model.objective = "bio1"
            mdlutl.pkgmgr.getpkg("KBaseMediaPkg").build_package(None)
            current_output["Growth"] = "Complete:"+str(mdlutl.model.slim_optimize())
        current_output["Reactions"] = mdlutl.nonexchange_reaction_count()
        current_output["Model genes"] = len(mdlutl.model.genes)
        return current_output
    
    def gapfill_metabolic_models(self,input):
        if input["media_obj"] == None:
            input["media_obj"] = self.get_media(input["media"])
        if input["model_obj"] == None:
            input["model_obj"] = FBAModel({'id':input["parameters"]["fbamodel_output_id"], 'name':input["genome"]["scientific_name"]})
        mdlutl = input["model_obj"]
        if self.core_template == None:
            self.core_template = self.get_template(self.kbase_templates["core"])
        if "output_data" not in input:
            input["output_data"] = {"Model":None,"Genome":None,"Genes":None,"Class":None,"Model genes":None,"Reactions":None,"Core GF":None,"GS GF":None,"Growth":None,"Comments":[]}
            input["output_data"]["Model"] = input["parameters"]["fbamodel_output_id"]
        #Computing tests for ATP safe gapfilling
        tests = mdlutl.get_atp_tests(core_template=self.core_template,atp_media_filename=input["config"]["ModelSEEDpy"]["codebase"]+"ModelSEEDpy/modelseedpy/data/atp_medias.tsv",recompute=False)
        #Creating gapfilling object and configuring solver
        if not input["template"]:
            template_id = mdlutl.model.template_ref.split("/")[-1]
            if template_id[-2:] == "||":
                template_id = template_id[:-2]
            input["template"] = self.get_template(template_id)
        msgapfill = MSGapfill(
            mdlutl,
            [input["template"]],
            [],
            tests,
            blacklist=[],
            default_target="bio1",
            minimum_obj=0.01,
            base_media=None,
            base_media_target_element=None
        )
        #Setting reaction scores from genome
        msgapfill.reaction_scores = {}
        #Running gapfilling in all conditions
        mdlutl.gfutl.cumulative_gapfilling = []
        growth_array = []
        solutions = msgapfill.run_multi_gapfill(
            [input["media_obj"]],
            target="bio1",
            default_minimum_objective=0.01,
            binary_check=False,
            prefilter=True,
            check_for_growth=True,
            gapfilling_mode="Sequential",
            run_sensitivity_analysis=True,
            integrate_solutions=True
        )
        output_solution = None
        output_solution_media = None
        media = input["media_obj"]
        if media in solutions and "growth" in solutions[media]:
            growth_array.append(media.id+":"+str(solutions[media]["growth"]))
            if solutions[media]["growth"] > 0 and output_solution == None:
                mdlutl.pkgmgr.getpkg("KBaseMediaPkg").build_package(media)
                mdlutl.pkgmgr.getpkg("ElementUptakePkg").build_package({"C": 60})
                output_solution = cobra.flux_analysis.pfba(mdlutl.model)
                output_solution_media = media
        solution_rxn_types = ["new","reversed"]
        if output_solution and output_solution_media in solutions:
            gfsolution = solutions[output_solution_media]
            for rxn_type in solution_rxn_types:
                for rxn_id in gfsolution[rxn_type]:
                    if gfsolution[rxn_type][rxn_id] == ">":
                        output_solution.fluxes[rxn_id] = 1000
                    else:
                        output_solution.fluxes[rxn_id] = -1000
        input["output_data"]["Growth"] = "<br>".join(growth_array)
        input["output_data"]["GS GF"] = len(mdlutl.gfutl.cumulative_gapfilling)
        input["output_data"]["Reactions"] = mdlutl.nonexchange_reaction_count()
        input["output_data"]["Model genes"] = len(mdlutl.model.genes)
        #Saving completely gapfilled model
        self.save_model(mdlutl)
        self.save_solution_as_fba(output_solution,mdlutl,output_solution_media,mdlutl.model.id+"."+media.id+".gf")
        return input["output_data"]
    
util = ModelSEEDReconPATRIC(input["config"])
output = util.build_metabolic_models(input)
util.print_json_debug_file(util.config["Scheduler"]["jobdirectory"]+"/jobs/"+util.config["Scheduler"]["jobid"]+"/script_output.json",output)