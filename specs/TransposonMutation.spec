/* Service for all different sorts of Expression data (microarray, RNA_seq, proteomics, qPCR */
module KBaseTransposonMutation { 

    /* 
        KBase Feature ID for a feature, typically CDS/PEG
        id ws KB.Feature 

        "ws" may change to "to" in the future 
    */
    typedef string feature_id;
    
    /* KBase list of Feature IDs , typically CDS/PEG */
    typedef list<feature_id> feature_ids;
    
    /* Measurement Value (Zero median normalized within a sample) for a given feature */
    typedef float measurement;
    
    /* KBase Sample ID for the sample */
    typedef string sample_id;
    
    /* List of KBase Sample IDs */
    typedef list<sample_id> sample_ids;

    /* List of KBase Sample IDs that this sample was averaged from */
    typedef list<sample_id> sample_ids_averaged_from;
    
    /* Sample type controlled vocabulary : microarray, RNA-Seq, qPCR, or proteomics */
    typedef string sample_type;
    
    /* Kbase Series ID */ 
    typedef string series_id; 
    
    /* list of KBase Series IDs */
    typedef list<series_id> series_ids;
    
    /* Kbase ExperimentMeta ID */ 
    typedef string experiment_meta_id; 
    
    /* list of KBase ExperimentMeta IDs */
    typedef list<experiment_meta_id> experiment_meta_ids;
    
    /* Kbase ExperimentalUnit ID */ 
    typedef string experimental_unit_id; 
    
    /* list of KBase ExperimentalUnit IDs */
    typedef list<experimental_unit_id> experimental_unit_ids;
    
    /* Mapping between sample id and corresponding value.   Used as return for get_expression_samples_(titles,descriptions,molecules,types,external_source_ids)*/
    typedef mapping<sample_id sampleID, string value> samples_string_map;

    /* Mapping between sample id and corresponding value.   Used as return for get_expression_samples_original_log2_median*/ 
    typedef mapping<sample_id sampleID, float originalLog2Median> samples_float_map;

    /* Mapping between sample id and corresponding value.   Used as return for get_series_(titles,summaries,designs,external_source_ids)*/ 
    typedef mapping<series_id seriesID, string value> series_string_map; 

    /* mapping kbase feature id as the key and measurement as the value */
    typedef mapping<feature_id featureID, measurement measurement> data_expression_levels_for_sample; 

    /*Mapping from Label (often a sample id, but free text to identify} to DataExpressionLevelsForSample */
    typedef mapping<string label, data_expression_levels_for_sample dataExpressionLevelsForSample> label_data_mapping;

    /* denominator label is the label for the denominator in a comparison.  
    This label can be a single sampleId (default or defined) or a comma separated list of sampleIds that were averaged.*/
    typedef string comparison_denominator_label;

    /* Log2Ratio Log2Level of sample over log2Level of another sample for a given feature.  
    Note if the Ratio is consumed by On Off Call function it will have 1(on), 0(unknown), -1(off) for its values */ 
    typedef float log2_ratio; 

    /* mapping kbase feature id as the key and log2Ratio as the value */ 
    typedef mapping<feature_id featureID, log2_ratio log2Ratio> data_sample_comparison; 

    /* mapping ComparisonDenominatorLabel to DataSampleComparison mapping */
    typedef mapping<comparison_denominator_label comparisonDenominatorLabel, data_sample_comparison dataSampleComparison> denominator_sample_comparison;

    /* mapping Sample Id for the numerator to a DenominatorSampleComparison.  This is the comparison data structure {NumeratorSampleId->{denominatorLabel -> {feature -> log2ratio}}} */
    typedef mapping<sample_id sampleID, denominator_sample_comparison denominatorSampleComparison> sample_comparison_mapping;

    /* Kbase SampleAnnotation ID */ 
    typedef string sample_annotation_id; 
 
    /* Kbase OntologyID  */ 
    typedef string ontology_id; 
    
    /* list of Kbase Ontology IDs */
    typedef list<ontology_id> ontology_ids;

    /* Kbase OntologyName */
    typedef string ontology_name;

    /* Kbase OntologyDefinition */
    typedef string ontology_definition;

	
}; 