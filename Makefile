TOP_DIR = ../..
include $(TOP_DIR)/tools/Makefile.common

TARGET ?= $(KB_TOP)
DEPLOY_RUNTIME ?= $(KB_RUNTIME)
SERVER_SPEC = ProbModelSEED.spec

SERVICE_MODULE = lib/Bio/ModelSEED/ProbModelSEED/Service.pm

SERVICE = ProbModelSEED
SERVICE_PORT = 7130

SERVICE_URL = http://p3.theseed.org/services/$(SERVICE)

SERVICE_NAME = ProbModelSEED
SERVICE_NAME_PY = $(SERVICE_NAME)

SERVICE_PSGI_FILE = /lib/$(SERVICE_NAME).psgi

SRC_SERVICE_PERL = $(wildcard service-scripts/*.pl)
BIN_SERVICE_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_SERVICE_PERL))))
DEPLOY_SERVICE_PERL = $(addprefix $(SERVICE_DIR)/bin/,$(basename $(notdir $(SRC_SERVICE_PERL))))


ifdef TEMPDIR
TPAGE_TEMPDIR = --define kb_tempdir=$(TEMPDIR)
endif

TPAGE_ARGS = --define kb_top=$(TARGET) \
	--define kb_runtime=$(DEPLOY_RUNTIME) \
	--define kb_service_name=$(SERVICE) \
	--define kb_service_port=$(SERVICE_PORT) \
	--define kb_service_psgi=$(SERVICE_PSGI_FILE) \
	$(TPAGE_TEMPDIR)

TESTS = $(wildcard t/client-tests/*.t)

all: bin service

jarfile:
	gen_java_client $(SERVER_SPEC) org.patricbrc.ProbModelSEED java
	javac java/org/patricbrc/ProbModelSEED/*java
	cd java; jar cf ../ProbModelSEED.jar org/patricbrc/ProbModelSEED/*.class

test:
	# run each test
	echo "RUNTIME=$(DEPLOY_RUNTIME)\n"
	for t in $(TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

service: $(SERVICE_MODULE)

compile-typespec: Makefile
	mkdir -p lib/biop3/$(SERVICE_NAME_PY)
	touch lib/biop3/__init__.py #do not include code in biop3/__init__.py
	touch lib/biop3/$(SERVICE_NAME_PY)/__init__.py 
	mkdir -p lib/javascript/$(SERVICE_NAME)
	compile_typespec \
		--psgi $(SERVICE_PSGI_FILE) \
		--impl Bio::ModelSEED::$(SERVICE_NAME)::$(SERVICE_NAME)Impl \
		--service Bio::ModelSEED::$(SERVICE_NAME)::Service \
		--client Bio::ModelSEED::$(SERVICE_NAME)::$(SERVICE_NAME)Client \
		--py biop3/$(SERVICE_NAME_PY)/$(SERVICE_NAME)Client \
		--js javascript/$(SERVICE_NAME)/$(SERVICE_NAME)Client \
		--url $(SERVICE_URL) \
		$(SERVER_SPEC) lib
	-rm -f lib/$(SERVER_MODULE)Server.py
	-rm -f lib/$(SERVER_MODULE)Impl.py

bin: $(BIN_PERL) $(BIN_SERVICE_PERL)

deploy: deploy-client deploy-service
deploy-all: deploy-client deploy-service
deploy-client: compile-typespec deploy-docs deploy-libs deploy-scripts 

deploy-service: deploy-dir deploy-monit deploy-libs deploy-service-scripts deploy-mfatoolkit deploy-cfg
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > $(TARGET)/services/$(SERVICE)/start_service
	chmod +x $(TARGET)/services/$(SERVICE)/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > $(TARGET)/services/$(SERVICE)/stop_service
	chmod +x $(TARGET)/services/$(SERVICE)/stop_service
	$(TPAGE) $(TPAGE_ARGS) service/log.conf.tt > $(TARGET)/services/$(SERVICE)/log.conf

deploy-service-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib ; \
	export PATH_PREFIX=$(TARGET)/services/$(SERVICE)/bin:$(TARGET)/services/cdmi_api/bin; \
	for src in $(SRC_SERVICE_PERL) ; do \
	        basefile=`basename $$src`; \
	        base=`basename $$src .pl`; \
	        echo install $$src $$base ; \
	        cp $$src $(TARGET)/plbin ; \
	        $(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/$$basefile" $(TARGET)/services/$(SERVICE)/bin/$$base ; \
	done

deploy-mfatoolkit:
	$(MAKE) -C MFAToolkit
	cp MFAToolkit/bin/mfatoolkit $(TARGET)/bin/
	if [ ! -e $(TARGET)/bin/scip ] ; then wget http://bioseed.mcs.anl.gov/~chenry/KbaseFiles/scip ; mv scip $(TARGET)/bin/ ; fi
	if [ ! -d $(TARGET)/etc/ ] ; then mkdir $(TARGET)/etc ; fi
	if [ ! -d $(TARGET)/etc/MFAToolkit ] ; then mkdir $(TARGET)/etc/MFAToolkit ; fi
	cp MFAToolkit/etc/MFAToolkit/* $(TARGET)/etc/MFAToolkit/
	chmod +x $(TARGET)/bin/scip
	chmod +x $(TARGET)/bin/mfatoolkit

deploy-monit:
	$(TPAGE) $(TPAGE_ARGS) service/process.$(SERVICE).tt > $(TARGET)/services/$(SERVICE)/process.$(SERVICE)

deploy-docs:
	if [ ! -d doc ] ; then mkdir doc ; fi
	if [ ! -d $(SERVICE_DIR) ] ; then mkdir $(SERVICE_DIR) ; fi
	if [ ! -d $(SERVICE_DIR)/webroot ] ; then mkdir $(SERVICE_DIR)/webroot ; fi
	$(DEPLOY_RUNTIME)/bin/pod2html -t "ProbModelSEED API" lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDImpl.pm > doc/probmodelseed_impl.html
	cp doc/*html $(SERVICE_DIR)/webroot/.

deploy-dir:
	if [ ! -d $(SERVICE_DIR) ] ; then mkdir $(SERVICE_DIR) ; fi
	if [ ! -d $(SERVICE_DIR)/webroot ] ; then mkdir $(SERVICE_DIR)/webroot ; fi
	if [ ! -d $(SERVICE_DIR)/bin ] ; then mkdir $(SERVICE_DIR)/bin ; fi

$(BIN_DIR)/%: service-scripts/%.pl $(TOP_DIR)/user-env.sh
	$(WRAP_PERL_SCRIPT) '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

$(BIN_DIR)/%: service-scripts/%.py $(TOP_DIR)/user-env.sh
	$(WRAP_PYTHON_SCRIPT) '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

include $(TOP_DIR)/tools/Makefile.common.rules