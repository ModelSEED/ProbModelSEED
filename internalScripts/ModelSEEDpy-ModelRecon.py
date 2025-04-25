import os
import sys
import uuid
import logging
import json
import argparse
import pandas as pd
from optlang.symbolics import Zero, add
import cobra
from cobrakbase.core.kbasefba import FBAModel
from modelseedpy import AnnotationOntology, MSPackageManager,MSGenome, MSMedia, MSModelUtil, MSBuilder, MSGapfill, FBAHelper, MSGrowthPhenotypes, MSModelUtil, MSATPCorrection,MSModelReport
from modelseedpy.helpers import get_template
from modelseedpy.core.msgenomeclassifier import MSGenomeClassifier
from modelseedpy.core.mstemplate import MSTemplateBuilder
from modelseedpy.core.msgenome import normalize_role
from kbbasemodules.basemodelingmodule import BaseModelingModule

logger = logging.getLogger(__name__)
# Parse command line arguments
parser = argparse.ArgumentParser(description='ModelSEED model reconstruction script')
parser.add_argument('parameters_file', help='JSON file containing input parameters')
args = parser.parse_args()

# Read parameters from JSON file
with open(args.parameters_file) as f:
    params = json.load(f)

class ModelSEEDReconPATRIC:
    def __init__(self,config,module_dir,working_dir=None):
        logging.basicConfig(format='%(created)s %(levelname)s: %(message)s',
                            level=logging.INFO)
        self.version = "0.1.1.bm"
        self.name = "ModelSEEDReconPATRIC"
        self.module_dir = module_dir
        self.config = config
        self.validate_args(self.config,[],{
            
        })
        self.cached_to_obj_path = {}
        if working_dir:
            self.working_dir = working_dir
        else:
            self.working_dir = config['scratch']
        self.reset_attributes()

        #Loading default biochemistry
        if "modelseedbiochem_directory" not in self.config or not self.config["modelseedbiochem_directory"]:
            #Setting location of ModelSEEDBiochem on Sequoia as the default, as that is where the most diverse users are
            self.config["modelseedbiochem_directory"] = "/scratch/shared/data/ModelSEEDDatabase"
        print("Loading ModelSEEDBiochem from "+self.config["modelseedbiochem_directory"])
        ModelSEEDBiochem.get(path=self.config["modelseedbiochem_directory"])
        #Loading default templates
        self.templates = {
            "core" : "Templates/Core-V5.2",
            "gp" : "Templates/GramPosModelTemplateV6",
            "gn" : "Templates/GramNegModelTemplateV6",
            "ar" : "Templates/ArchaeaTemplateV6",
            "grampos" : "Templates/GramPosModelTemplateV6",
            "gramneg" : "Templates/GramNegModelTemplateV6",
            "archaea" : "Templates/ArchaeaTemplateV6",
            "old_grampos" : "Templates/GramPosModelTemplateV3",
            "old_gramneg" : "Templates/GramNegModelTemplateV3",
            "custom": None
        }
        self.core_template = None
        self.util = None
        self.gs_template = None
        self.native_ontology = False
    
     #########METHOD CALL INITIALIZATION FUNCTIONS#######################
    def initialize_call(self,method,params,print_params=False,no_print=[],no_prov_params=[]):
        if not self.initialized:
            self.obj_created = []
            self.input_objects = []
            self.method = method
            self.params = copy.deepcopy(params)
            for item in no_prov_params:
                if item in self.params:
                    del self.params[item]
            self.initialized = True
            if "workspace" in params:
                self.set_ws(params["workspace"])
            elif "output_workspace" in params:
                self.set_ws(params["output_workspace"])
            if print_params:
                saved_data = {}
                for item in no_print:
                    if item in params:
                        saved_data[item] = params[item]
                        del params[item]
                logger.info(method+":"+json.dumps(params,indent=4))
                for item in saved_data:
                    params[item] = saved_data[item]

    #########GENERAL UTILITY FUNCTIONS#######################
    def validate_args(self,params,required,defaults):
        for item in required:
            if item not in params:
                raise ValueError('Required argument '+item+' is missing!')
        for key in defaults:
            if key not in params:
                params[key] = defaults[key]
        return params
    
    def transfer_outputs(self,output,api_output,key_list):
        for key in key_list:
            if key in api_output:
                output[key] = api_output[key]

    def save_json(self,name,data):
        with open(self.working_dir+'/'+name+".json", 'w') as f:
            json.dump(data, f,indent=4,skipkeys=True)

    def load_json(self,name,default={}):
        if exists(self.working_dir+'/'+name+".json"):
            with open(self.working_dir+'/'+name+".json", 'r') as f:
                return json.load(f)
        return default
    
    def print_json_debug_file(self,filename,data):
        print("Printing debug file:",self.working_dir+'/'+filename)
        with open(self.working_dir+'/'+filename, 'w') as f:
            json.dump(data, f,indent=4,skipkeys=True)

    #################Utility functions#####################
    def process_media_list(self,media_list,default_media,workspace):
        if not media_list:
            media_list = []
        #Retrieving media objects from references
        media_objects = []
        first = True
        #Cleaning out empty or invalid media references
        original_list = media_list
        media_list = []
        for media_ref in original_list:
            if not media_ref or len(media_ref) == 0:
                if first:
                    media_list.append(default_media)
                    first = False
                else:
                    print("Filtering out empty media reference")
            elif len(media_ref.split("/")) == 1:
                media_list.append(str(workspace)+"/"+media_ref)
            elif len(media_ref.split("/")) <= 3:
                media_list.append(media_ref)
            else:
                print(media_ref+" looks like an invalid workspace reference")
        #Making sure default gapfilling media is complete media
        if not media_list or len(media_list) == 0:
            media_list = [default_media]            
        #Retrieving media objects        
        for media_ref in media_list:  
            media = self.get_media(media_ref,None)
            media_objects.append(media)
        return media_objects
    
    def create_minimal_medias(self,carbon_list,workspace,base_media="KBaseMedia/Carbon-D-Glucose"):
        data = self.get_object(base_media)["data"]
        for item in carbon_list:
            self.save_json("Carbon-"+item,data)
            copy = self.load_json("Carbon-"+item)
            copy["id"] = "Carbon-"+item
            copy["name"] = "Carbon-"+item
            copy["source_id"] = "Carbon-"+item
            copy["type"] = "MinimalCarbon"
            for cpd in copy["mediacompounds"]:
                if cpd["compound_ref"].split("/")[-1] == "cpd00027":
                    cpd["compound_ref"] = cpd["compound_ref"].replace("cpd00027",carbon_list[item])
            self.save_ws_object("Carbon-"+item,workspace,copy,"KBaseBiochem.Media")
    
    #################Genome functions#####################
    def annotate_genome_with_rast(self,genome_id,ws=None,output_ws=None):
        if not output_ws:
            output_ws = ws
        rast_client = self.rast_client()
        output = rast_client.annotate_genome({
            "workspace": output_ws,
            "input_genome":genome_id,
            "output_genome":genome_id+".RAST"
        })
        return output["workspace"]+"/"+output["id"]
    
    def get_msgenome_from_ontology(self,id_or_ref,ws=None,native_python_api=False,output_ws=None):
        annoapi = self.anno_client(native_python_api=native_python_api)
        gen_ref = self.create_ref(id_or_ref,ws)
        genome_info = self.get_object_info(gen_ref)
        annoont = AnnotationOntology.from_kbase_data(annoapi.get_annotation_ontology_events({
            "input_ref" : gen_ref
        }),gen_ref,self.module_dir+"/data/")
        gene_term_hash = annoont.get_gene_term_hash(ontologies=["SSO"])
        if len(gene_term_hash) == 0:
            logger.warning("Genome has not been annotated with RAST! Reannotating genome with RAST!")
            gen_ref = self.annotate_genome_with_rast(genome_info[1],genome_info[6],output_ws)
            annoont = AnnotationOntology.from_kbase_data(annoapi.get_annotation_ontology_events({
                "input_ref" : gen_ref
            }),gen_ref,self.module_dir+"/data/")
        annoont.info = genome_info
        wsgenome = self.get_msgenome(gen_ref,ws)
        genome = annoont.get_msgenome()
        for ftr in wsgenome.features:
            for func in ftr.functions:
                if ftr.id in genome.features:
                    genome.features.get_by_id(ftr.id).add_ontology_term("RAST",func)
                else:
                    newftr = genome.create_new_feature(ftr.id,"")
                    newftr.add_ontology_term("RAST",func)
        genome.id = genome_info[1]
        genome.scientific_name = genome_info[10]["Name"]
        return genome

    def get_expression_objs(self,expression_refs,genome_objs):
        genomes_to_models_hash = {}
        for mdl in genome_objs:
            genomes_to_models_hash[genome_objs[mdl]] = mdl
        ftrhash = {}
        expression_objs = {}
        for genome_obj in genomes_to_models_hash:
            for ftr in genome_obj.features:
                ftrhash[ftr.id] = genome_obj
        for expression_ref in expression_refs:
            expression_obj = self.kbase_api.get_from_ws(expression_ref,None)
            row_ids = expression_obj.row_ids
            genome_obj_count = {}
            for ftr_id in row_ids:
                if ftr_id in ftrhash:
                    if ftrhash[ftr_id] not in genome_obj_count:
                        genome_obj_count[ftrhash[ftr_id]] = 0
                    genome_obj_count[ftrhash[ftr_id]] += 1
            best_count = None
            best_genome = None
            for genome_obj in genome_obj_count:
                if best_genome == None or genome_obj_count[genome_obj] > best_count:
                    best_genome = genome_obj
                    best_count = genome_obj_count[genome_obj]
            if best_genome:
                expression_objs[genomes_to_models_hash[best_genome]] = expression_obj.data    
        return expression_objs

    def get_msgenome(self,id_or_ref,ws=None):
        genome = self.kbase_api.get_from_ws(id_or_ref,ws)
        genome.id = genome.info.id
        self.input_objects.append(genome.info.reference)
        return genome
    
    def get_media(self,id_or_ref,ws=None):
        media = self.kbase_api.get_from_ws(id_or_ref,ws)
        media.id = media.info.id
        self.input_objects.append(media.info.reference)
        return media
    
    def get_phenotypeset(self,id_or_ref,ws=None,base_media=None, base_uptake=0, base_excretion=1000,global_atom_limits={}):
        kbphenoset = self.kbase_api.get_object(id_or_ref,ws)
        phenoset = MSGrowthPhenotypes.from_kbase_object(kbphenoset,self.kbase_api,base_media,base_uptake,base_excretion,global_atom_limits)
        return phenoset
    
    def get_model(self,id_or_ref,ws=None,is_json_file=False):
        if is_json_file:
            return MSModelUtil.build_from_kbase_json_file(id_or_ref)
        mdlutl = MSModelUtil(self.kbase_api.get_from_ws(id_or_ref,ws))
        mdlutl.wsid = mdlutl.model.info.id
        self.input_objects.append(mdlutl.model.info.reference)
        return mdlutl
    
    def extend_model_with_other_ontologies(self,mdlutl,anno_ont,builder,prioritized_event_list=None,ontologies=None,merge_all=True):
        gene_term_hash = anno_ont.get_gene_term_hash(
            prioritized_event_list, ontologies, merge_all, False
        )
        self.print_json_debug_file("gene_term_hash",gene_term_hash)
        residual_reaction_gene_hash = {}
        for gene in gene_term_hash:
            for term in gene_term_hash[gene]:
                if term.ontology.id != "SSO":
                    for rxn_id in term.msrxns:
                        if rxn_id not in residual_reaction_gene_hash:
                            residual_reaction_gene_hash[rxn_id] = {}
                        if gene not in residual_reaction_gene_hash[rxn_id]:
                            residual_reaction_gene_hash[rxn_id][gene] = []
                        residual_reaction_gene_hash[rxn_id][gene] = gene_term_hash[gene][term]

        reactions = []
        SBO_ANNOTATION = "sbo"
        modelseeddb = ModelSEEDBiochem.get()
        biochemdbrxn = False
        for rxn_id in residual_reaction_gene_hash:
            if rxn_id + "_c0" not in mdlutl.model.reactions:
                reaction = None
                template_reaction = None
                if rxn_id + "_c" in mdlutl.model.template.reactions:
                    template_reaction = mdlutl.model.template.reactions.get_by_id(rxn_id + "_c")
                elif rxn_id in modelseeddb.reactions:
                    rxnobj = modelseeddb.reactions.get_by_id(rxn_id)
                    if "MI" not in rxnobj.status and "CI" not in rxnobj.status:
                        #mdlutl.add_ms_reaction({rxn_id:"c0"}, compartment_trans=["c0", "e0"])
                        template_reaction = rxnobj.to_template_reaction({0: "c", 1: "e"})
                        biochemdbrxn = True
                if template_reaction:
                    for m in template_reaction.metabolites:
                        if m.compartment not in builder.compartments:
                            builder.compartments[
                                m.compartment
                            ] = builder.template.compartments.get_by_id(m.compartment)
                        if m.id not in builder.template_species_to_model_species:
                            model_metabolite = m.to_metabolite(builder.index)
                            builder.template_species_to_model_species[
                                m.id
                            ] = model_metabolite
                            builder.base_model.add_metabolites([model_metabolite])
                    if biochemdbrxn:
                        pass
                        #template_reaction.add_metabolites({})
                    reaction = template_reaction.to_reaction(
                        builder.base_model, builder.index
                    )
                    gpr = ""
                    probability = None
                    for gene in residual_reaction_gene_hash[rxn_id]:
                        for item in residual_reaction_gene_hash[rxn_id][gene]:
                            if "scores" in item:
                                if "probability" in item["scores"]:
                                    if (
                                        not probability
                                        or item["scores"]["probability"] > probability
                                    ):
                                        probability = item["scores"]["probability"]
                        if len(gpr) > 0:
                            gpr += " or "
                        gpr += gene.id
                    if probability != None and hasattr(reaction, "probability"):
                        reaction.probability = probability
                    reaction.gene_reaction_rule = gpr
                    reaction.annotation[SBO_ANNOTATION] = "SBO:0000176"
                    reactions.append(reaction)
                if not reaction:
                    print("Reaction ", rxn_id, " not found in template or database!")
            else:
                rxn = mdlutl.model.reactions.get_by_id(rxn_id + "_c0")
                gpr = rxn.gene_reaction_rule
                probability = None
                for gene in residual_reaction_gene_hash[rxn_id]:
                    for item in residual_reaction_gene_hash[rxn_id][gene]:
                        if "scores" in item:
                            if "probability" in item["scores"]:
                                if (
                                    not probability
                                    or item["scores"]["probability"] > probability
                                ):
                                    probability = item["scores"]["probability"]
                    if len(gpr) > 0:
                        gpr += " or "
                    gpr += gene.id
                if probability != None and hasattr(rxn, "probability"):
                    rxn.probability = probability
                rxn.gene_reaction_rule = gpr
        mdlutl.model.add_reactions(reactions)
        return mdlutl
    
    #################Classifier functions#####################
    def get_classifier(self):
        cls_pickle = self.config["data"]+"/knn_ACNP_RAST_full_01_17_2023.pickle"
        cls_features = self.config["data"]+"/knn_ACNP_RAST_full_01_17_2023_features.json"
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
    
    def get_template(self,template_id,ws=None):
        template = self.kbase_api.get_from_ws(template_id,ws)
        #template = self.kbase_api.get_object(template_id,ws)
        #info = self.kbase_api.get_object_info(template_id,ws)
        #template = MSTemplateBuilder.from_dict(template).build()
        self.input_objects.append(template.info.reference)
        return template

    #################Save functions#####################
    def save_model(self,mdlutl,workspace=None,objid=None,suffix=None):
        #Checking for zero flux reactions
        for rxn in mdlutl.model.reactions:
            if rxn.lower_bound == 0 and rxn.upper_bound == 0:
                print("Zero flux reaction: "+rxn.id)
        #Setting the ID based on input
        if not suffix:
            suffix = ""
        if not objid:
            objid = mdlutl.wsid
        if not objid:
            logger.critical("Must provide an ID to save a model!")
        objid = objid+suffix
        mdlutl.wsid = objid
        #Saving attributes and getting model data
        if not isinstance(mdlutl.model,FBAModel):
            mdlutl.model = CobraModelConverter(mdlutl.model).build()
        mdlutl.save_attributes()
        data = mdlutl.model.get_data()
        #If the workspace is None, then saving data to file
        if not workspace:
            self.print_json_debug_file(mdlutl.wsid+".json",data)
        else:
            #Setting the workspace
            if workspace:
                self.set_ws(workspace)
            #Setting provenance and saving model using workspace API
            mdlutl.create_kb_gapfilling_data(data,self.config["ATP_media_workspace"])
            params = {
                'id':self.ws_id,
                'objects': [{
                    'data': data,
                    'name': objid,
                    'type': "KBaseFBA.FBAModel",
                    'meta': {},
                    'provenance': self.provenance()
                }]
            }
            self.ws_client().save_objects(params)
            self.obj_created.append({"ref":self.create_ref(objid,self.ws_name),"description":""})
    
    def save_phenotypeset(self,data,workspace,objid):
        self.set_ws(workspace)
        params = {
            'id':self.ws_id,
            'objects': [{
                'data': data,
                'name': objid,
                'type': "KBasePhenotypes.PhenotypeSet",
                'meta': {},
                'provenance': self.provenance()
            }]
        }
        self.ws_client().save_objects(params)
        self.obj_created.append({"ref":self.create_ref(objid,self.ws_name),"description":""})

    def save_solution_as_fba(self,fba_or_solution,mdlutl,media,fbaid,workspace=None,fbamodel_ref=None,other_solutions=None):
        if not isinstance(fba_or_solution,MSFBA):
            fba_or_solution = MSFBA(mdlutl,media,primary_solution=fba_or_solution)
        fba_or_solution.id = fbaid
        if other_solutions != None:
            for other_solution in other_solutions:
                fba_or_solution.add_secondary_solution(other_solution)
        data = fba_or_solution.generate_kbase_data(fbamodel_ref,media.info.reference)
        #If the workspace is None, then saving data to file
        if not workspace and self.util:
            self.util.save(fbaid,data)
        else:
            #Setting the workspace
            if workspace:
                self.set_ws(workspace)
            #Setting provenance and saving model using workspace API
            params = {
                'id':self.ws_id,
                'objects': [{
                    'data': data,
                    'name': fbaid,
                    'type': "KBaseFBA.FBA",
                    'meta': {},
                    'provenance': self.provenance()
                }]
            }
            self.ws_client().save_objects(params)
            self.obj_created.append({"ref":self.create_ref(fbaid,self.ws_name),"description":""})

    #Primary functions
    def build_metabolic_models(self,params):
        default_media = "/chenry/public/modelsupport/media/AuxoMedia"
        self.initialize_call("build_metabolic_models",params,True)
        self.validate_args(params,["workspace"],{
            "genome_refs":[],
            "run_gapfilling":False,
            "atp_safe":True,
            "forced_atp_list":[],
            "gapfilling_media_list":None,
            "suffix":".mdl",
            "core_template":"auto",
            "gs_template":"auto",
            "gs_template_ref":None,
            "core_template_ref":None,
            "template_reactions_only":True,
            "output_core_models":False,
            "automated_atp_evaluation":True,
            "atp_medias":[],
            "load_default_medias":True,
            "max_gapfilling":10,
            "gapfilling_delta":0,
            "return_model_objects":False,
            "return_data":False,
            "save_report_to_kbase":True,
            "change_to_complete":False,
            "gapfilling_mode":"Sequential",
            "base_media":None,
            "compound_list":None,
            "base_media_target_element":"C",
            "expression_refs":None,
            "extend_model_with_ontology":False,
            "ontology_events":None,
            "save_models_to_kbase":True,
            "save_gapfilling_fba_to_kbase":True,
            "annotation_priority":[],
            "merge_annotations":False
        })
        if params["change_to_complete"]:
            default_media = "/chenry/public/modelsupport/media/Complete"
        params["genome_refs"] = self.process_genome_list(params["genome_refs"],params["workspace"])
        #Processing media
        params["gapfilling_media_objs"] = self.process_media_list(params["gapfilling_media_list"],default_media,params["workspace"])
        #Preloading core and preselected template - note the default GS template is None because this signals for the classifier to be used to select the template
        self.gs_template = None
        if params["gs_template_ref"] != None and not isinstance(params["gs_template_ref"],str):
            #Allows user to directly set the GS template object by passing the object in gs_template_ref
            self.gs_template = params["gs_template_ref"]
        if params["gs_template_ref"]:
            #Allows user to set the workspace ID of the GS template to be used
            self.gs_template = self.get_template(params["gs_template_ref"],None)
        if params["core_template_ref"] != None and not isinstance(params["core_template_ref"],str):
            #Allows user to directly set the core template object by passing the object in core_template_ref
            self.core_template = params["core_template_ref"]
        elif params["core_template_ref"]:
            #Allows user to set the workspace ID of the core template to be used
            self.core_template = self.get_template(params["core_template_ref"],None)
        else:
            #Setting the default core template
            self.core_template = self.get_template(self.templates["core"],None)  
        #Initializing classifier
        genome_classifier = self.get_classifier()
        #Initializing output data tables
        result_table = pd.DataFrame({})
        default_output = {"Model":None,"Genome":None,"Genes":None,"Class":None,
                          "Model genes":None,"Reactions":None,
                          "Core GF":None,"GS GF":None,"Growth":None,"Comments":[]}
        #Retrieving genomes and building models one by one
        mdllist = []
        for i,gen_ref in enumerate(params["genome_refs"]):
            template_type = params["gs_template"]
            #Getting RAST annotated genome, which will be reannotated as needed
            genome = self.get_msgenome_from_ontology(gen_ref,native_python_api=self.native_ontology,output_ws=params["workspace"])
            #Initializing output row
            current_output = default_output.copy()
            current_output["Comments"] = []
            gid = genome.id
            current_output["Model"] = gid+params["suffix"]+'<br><a href="'+gid+params["suffix"]+'-recon.html" target="_blank">(see reconstruction report)</a><br><a href="'+gid+params["suffix"]+'-full.html" target="_blank">(see full view)</a>'
            current_output["Genome"] = genome.annoont.info[10]["Name"]
            current_output["Genes"] = genome.annoont.info[10]["Number of Protein Encoding Genes"]
            #Pulling annotation priority
            current_output["Comments"].append("Other annotation priorities not supported by this app yet. Using RAST.")
            if template_type == "auto":
                current_output["Class"] = genome_classifier.classify(genome)
                print(current_output["Class"])
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
                    continue
                else:
                    current_output["Comments"].append("Unrecognized genome class "+current_output["Class"]+". Skipping genome.")
                    result_table = result_table.append(current_output, ignore_index = True)
                    continue
            if not self.gs_template:
                self.gs_template = self.get_template(self.templates[template_type],None)
            #Building model            
            base_model = FBAModel({'id':gid+params["suffix"], 'name':genome.scientific_name})
            builder = MSBuilder(genome, self.gs_template)
            mdl = builder.build(base_model, '0', False, False)            
            mdl.genome = genome
            mdl.template = self.gs_template
            mdl.core_template_ref = str(self.core_template.info)
            mdl.genome_ref = self.wsinfo_to_ref(genome.annoont.info)
            mdl.template_ref = str(self.gs_template.info)
            current_output["Core GF"] = "NA" 
            mdlutl = MSModelUtil.get(mdl)
            if params["extend_model_with_ontology"] or len(params["annotation_priority"]) > 0:
                #Removing reactions from model that are not in the core
                remove_list = []
                #Remove all non-core reactions IF RAST is not included in annotation priorities
                if "RAST" not in params["annotation_priority"] and "all" not in params["annotation_priority"]:
                    for rxn in mdl.reactions:
                        if not mdlutl.is_core(rxn) and rxn.id[0:3] != "bio" and rxn.id[0:3] != "DM_" and rxn.id[0:3] != "EX_" and rxn.id[0:3] != "SK_":
                            remove_list.append(rxn.id)
                    mdl.remove_reactions(remove_list)
                #Now extending model with selected ontology priorities
                if params["ontology_events"] == None and len(params["annotation_priority"]) > 0:
                    params["ontology_events"] = genome.annoont.get_events_from_priority_list(params["annotation_priority"])
                self.extend_model_with_other_ontologies(mdlutl,genome.annoont,builder,prioritized_event_list=params["ontology_events"],merge_all=params["merge_annotations"])
            mdlutl.save_model("base_model.json")
            genome_objs = {mdlutl:genome}
            expression_objs = None
            if params["expression_refs"]:
                expression_objs = self.get_expression_objs(params["expression_refs"],genome_objs)
            if params["atp_safe"]:
                atpcorrection = MSATPCorrection(mdlutl,self.core_template,params["atp_medias"],load_default_medias=params["load_default_medias"],max_gapfilling=params["max_gapfilling"],gapfilling_delta=params["gapfilling_delta"],forced_media=params["forced_atp_list"],default_media_path=self.module_dir+"/data/atp_medias.tsv")
                tests = atpcorrection.run_atp_correction()
                current_output["Core GF"] = len(atpcorrection.cumulative_core_gapfilling)
            #Setting the model ID so the model is saved with the correct name in KBase
            mdlutl.get_attributes()["class"] = current_output["Class"]
            mdlutl.wsid = gid+params["suffix"]
            #Running gapfilling
            current_output["GS GF"] = "NA"
            if params["run_gapfilling"]:
                self.gapfill_metabolic_models({
                    "media_objs":params["gapfilling_media_objs"],#
                    "model_objs":[mdlutl],#
                    "genome_objs":genome_objs,#
                    "expression_objs":expression_objs,#
                    "atp_safe":params["atp_safe"],#
                    "workspace":params["workspace"],#
                    "suffix":"",#
                    "default_objective":"bio1",#
                    "output_data":{mdlutl:current_output},#
                    "forced_atp_list":params["forced_atp_list"],
                    "templates":[self.gs_template],
                    "internal_call":True,
                    "gapfilling_mode":params["gapfilling_mode"],
                    "base_media":params["base_media"],
                    "compound_list":params["compound_list"],
                    "base_media_target_element":params["base_media_target_element"],
                    "save_models_to_kbase":params["save_models_to_kbase"],
                    "save_gapfilling_fba_to_kbase":params["save_gapfilling_fba_to_kbase"]
                })
            else:
                if params["save_models_to_kbase"]:
                    self.save_model(mdlutl,params["workspace"],None)
                mdlutl.model.objective = "bio1"
                mdlutl.pkgmgr.getpkg("KBaseMediaPkg").build_package(None)
                current_output["Growth"] = "Complete:"+str(mdlutl.model.slim_optimize())
            current_output["Reactions"] = mdlutl.nonexchange_reaction_count()
            current_output["Model genes"] = len(mdlutl.model.genes)
            #if params["output_core_models"]:
            #TODO: Remove noncore reactions and change biomass and change model ID and then resave
            #Filling in model output
            result_table = pd.concat([result_table, pd.DataFrame([current_output])], ignore_index=True)
            mdllist.append(mdlutl)
        output = {}
        self.build_dataframe_report(result_table,mdllist)
        if params["save_report_to_kbase"]:
            output = self.save_report_to_kbase()
        if params["return_data"]:
            output["data"] = result_table.to_json()
        if params["return_model_objects"]:
            output["model_objs"] = mdllist
        return output
    
    def gapfill_metabolic_models(self,params):
        default_media = "/chenry/public/modelsupport/media/AuxoMedia"
        self.initialize_call("gapfill_metabolic_models",params,True)
        self.validate_args(params,["workspace"],{
            "media_list":None,
            "media_objs":None,
            "genome_objs":None,
            "expression_refs":None,
            "expression_objs":None,
            "model_list":None,
            "model_objectives":[],
            "model_objs":[],
            "atp_safe":True,
            "suffix":".gf",
            "forced_atp_list":[],
            "templates":None,
            "core_template_ref":None,
            "source_models":[],
            "limit_medias":[],
            "limit_objectives":[],
            "limit_thresholds":[],
            "is_max_limits":[],
            "minimum_objective":0.01,
            "reaction_exlusion_list":[],
            "default_objective":"bio1",
            "kbmodel_hash":{},
            "output_data":None,
            "internal_call":False,
            "atp_medias":[],
            "load_default_atp_medias":True,
            "max_atp_gapfilling":0,
            "gapfilling_delta":0,
            "return_model_objects":False,
            "return_data":False,
            "save_report_to_kbase":True,
            "change_to_complete":False,
            "gapfilling_mode":"Sequential",
            "base_media":None,
            "compound_list":None,
            "base_media_target_element":"C",
            "save_models_to_kbase":True,
            "save_gapfilling_fba_to_kbase":True
        })
        base_comments = []
        if params["change_to_complete"]:
            base_comments.append("Changing default to complete.")
            default_media = "KBaseMedia/Complete"
        result_table = pd.DataFrame({})
        default_output = {"Model":None,"Genome":None,"Genes":None,"Class":None,
            "Model genes":None,"Reactions":None,"Core GF":None,"GS GF":None,"Growth":None,"Comments":[]}
        #Retrieving models if not provided already
        if "model_objs" not in params or len(params["model_objs"]) == 0:
            params["model_objs"] = []
            for mdl_ref in params["model_list"]:
                params["model_objs"].append(self.get_model(mdl_ref))
        #Retrieving genomes if not provided already
        if not params["genome_objs"]:
            params["genome_objs"] = {}
            for mdl in params["model_objs"]:
                params["genome_objs"][mdl] = self.get_msgenome_from_ontology(mdl.model.genome_ref,native_python_api=self.native_ontology,output_ws=params["workspace"])
        #Retrieving expression data if not provided already
        if not params["expression_objs"] and params["expression_refs"]:
            params["expression_objs"] = self.get_expression_objs(params["expression_refs"],params["genome_objs"])
        #Processing media
        if not params["media_objs"]:
            params["media_objs"] = self.process_media_list(params["media_list"],default_media,params["workspace"])
        #Processing compound list
        if params["compound_list"]:
            if not params["base_media"]:
                base_comments.append("No base media provided. Ignoring compound list.")
            else:
                for cpd in params["compound_list"]:
                    newmedia = MSMedia.from_dict({cpd:100})
                    newmedia.merge(params["base_media"])
                    params["media_objs"].append(newmedia)
        #Compiling additional tests
        additional_tests = []
        for i,limit_media in enumerate(params["limit_medias"]):
            additional_tests.append({
                "objective":params["limit_objectives"][i],
                "media":self.get_media(limit_media,None),
                "is_max_threshold":params["is_max_limits"][i],
                "threshold":params["limit_thresholds"][i]
            })
        #Getting core template
        if params["core_template_ref"]:
            self.core_template = self.get_template(params["core_template_ref"],None)
        else:
            self.core_template = self.get_template(self.templates["core"],None)
        #Iterating over each model and running gapfilling
        for i,mdlutl in enumerate(params["model_objs"]):
            current_output = default_output.copy()
            current_output["Comments"] = base_comments
            current_output["Model"] = mdlutl.wsid+params["suffix"]+'<br><a href="'+mdlutl.wsid+params["suffix"]+'-recon.html" target="_blank">(see reconstruction report)</a><br><a href="'+mdlutl.wsid+params["suffix"]+'-full.html" target="_blank">(see full view)</a>'
            if params["output_data"] and mdlutl in params["output_data"]:
                current_output = params["output_data"][mdlutl]
            #Setting the objective
            if i < len(params["model_objectives"]):
                if not params["model_objectives"][i]:
                    params["model_objectives"][i] = params["default_objective"]
            else:
                params["model_objectives"].append(params["default_objective"])
            #Computing tests for ATP safe gapfilling
            if params["atp_safe"]:
                tests = mdlutl.get_atp_tests(core_template=self.core_template,atp_media_filename=self.module_dir+"/data/atp_medias.tsv",recompute=False)
                print("Tests:",tests)
                additional_tests.extend(tests)
            #Creating gapfilling object and configuring solver
            #mdlutl.model.solver = config["solver"]
            if not params["templates"]:
                params["templates"] = [self.get_template(mdlutl.model.template_ref)]
            msgapfill = MSGapfill(
                mdlutl,
                params["templates"],
                params["source_models"],
                additional_tests,
                blacklist=params["reaction_exlusion_list"],
                default_target=params["model_objectives"][i],
                minimum_obj=params["minimum_objective"],
                base_media=params["base_media"],
                base_media_target_element=params["base_media_target_element"]
            )
            #Setting reaction scores from genome
            msgapfill.reaction_scores = params["genome_objs"][mdlutl].annoont.get_reaction_gene_hash(feature_type="gene")
            if self.util:
                self.util.save("original_scores",msgapfill.reaction_scores)
            if params["expression_objs"] and mdlutl in params["expression_objs"] and mdlutl in params["genome_objs"]:
                expression_scores = msgapfill.compute_reaction_weights_from_expression_data(params["expression_objs"][mdlutl],params["genome_objs"][mdlutl].annoont)
                for rxn_id in msgapfill.reaction_scores:
                    for gene in msgapfill.reaction_scores[rxn_id]:
                        if gene in expression_scores:
                            msgapfill.reaction_scores[rxn_id][gene]["probability"] = expression_scores[gene]+0.5
                if self.util:
                    self.util.save("expression_scores",msgapfill.reaction_scores)   
            #Running gapfilling in all conditions
            mdlutl.gfutl.cumulative_gapfilling = []
            growth_array = []
            solutions = msgapfill.run_multi_gapfill(
                params["media_objs"],
                target=params["model_objectives"][i],
                default_minimum_objective=params["minimum_objective"],
                binary_check=False,
                prefilter=True,
                check_for_growth=True,
                gapfilling_mode=params["gapfilling_mode"],
                run_sensitivity_analysis=True,
                integrate_solutions=True
            )
            output_solution = None
            output_solution_media = None
            for media in params["media_objs"]:
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
            current_output["Growth"] = "<br>".join(growth_array)
            current_output["GS GF"] = len(mdlutl.gfutl.cumulative_gapfilling)
            current_output["Reactions"] = mdlutl.nonexchange_reaction_count()
            current_output["Model genes"] = len(mdlutl.model.genes)
            #Saving completely gapfilled model
            if params["save_models_to_kbase"]:
                self.save_model(mdlutl,params["workspace"],None,params["suffix"])
            if params["save_gapfilling_fba_to_kbase"] and output_solution:
                self.save_solution_as_fba(output_solution,mdlutl,output_solution_media,mdlutl.wsid+".fba",workspace=params["workspace"],fbamodel_ref=str(params["workspace"])+"/"+mdlutl.wsid)
            if not params["internal_call"]:
                result_table = pd.concat([result_table, pd.DataFrame([current_output])], ignore_index=True)
        output = {}
        if not params["internal_call"]:
            self.build_dataframe_report(result_table,params["model_objs"])
            if params["save_report_to_kbase"]:
                output = self.save_report_to_kbase()
            if params["return_data"]:
                output["data"] = result_table.to_json()
            if params["return_model_objects"]:
                output["model_objs"] = params["model_objs"]
        return output
