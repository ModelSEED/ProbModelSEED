compile_typespec \
	-impl Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl \
	-service Bio::ModelSEED::ProbModelSEED::Service \
	-psgi ProbModelSEED.psgi \
	-client Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient \
	-js javascript/ProbModelSEED/ProbModelSEEDClient \
	-py biop3/ProbModelSEED/ProbModelSEEDClient \
	ProbModelSEED.spec lib


