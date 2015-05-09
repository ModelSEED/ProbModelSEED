compile_typespec \
	-impl Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl \
	-service Bio::ModelSEED::ProbModelSEED::Server \
	-psgi ProbModelSEED.psgi \
	-client Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient \
	-js javascript/ProbModelSEED/ProbModelSEEDClient \
	-py biop3/ProbModelSEED/ProbModelSEEDClient \
	ProbModelSEED.spec lib


