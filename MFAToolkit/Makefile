# check if kbase module
TOP_DIR = ../..
IN_KBASE=0
ifeq ($(wildcard TOP_DIR/tools/Makefile.common),'')
	include $(TOP_DIR)/tools/Makefile.common
	IN_KBASE=1
endif

CWD= $(shell pwd)
# CC
CC = g++

# LIBS
GLPKLIB = -L/homes/chenry/Software/glpk-4.37/src/.libs -lpthread -lglpk
CPLEXLIB =  -lcplex -lm
LIBS = -lz ${GLPKLIB} ${CPLEXLIB}

# INCS
MFATK_INC = -I${CWD}/include -I/homes/chenry/Software/glpk-4.37/include -L/vol/kbase/deployment/bin -I/vol/kbase/runtime/include
CPLEXINC = -I/vol/model-prod/Software/cplex/cplex/include/ilcplex/ -L/vol/model-prod/Software/cplex/cplex/lib/x86-64_sles10_4.1/static_pic/
INCS = ${MFATK_INC} ${CPLEXINC}

# FLAGS
OFLAGS = -DLINUX -DNDEBUG -DIL_STD -DILOSTRICTPOD -DNOSAFEMEM -DNOBLOCKMEM -O3
FFLAGS = -fPIC -fexceptions

# CCFLAGS
CCFLAGS = ${INCS} ${OFLAGS} ${FFLAGS}
LDFLAGS = ${LIBS}

CPLEXAPI = CPLEXapi.cpp
SRCDIR=${CWD}/src

SRCFILES = ${SRCDIR}/driver.cpp ${SRCDIR}/MFAProblem.cpp ${SRCDIR}/${CPLEXAPI} ${SRCDIR}/SCIPapi.cpp ${SRCDIR}/GLPKapi.cpp ${SRCDIR}/LINDOapiEMPTY.cpp ${SRCDIR}/SolverInterface.cpp ${SRCDIR}/Species.cpp ${SRCDIR}/Data.cpp ${SRCDIR}/InterfaceFunctions.cpp ${SRCDIR}/Identity.cpp ${SRCDIR}/Reaction.cpp ${SRCDIR}/GlobalFunctions.cpp ${SRCDIR}/AtomCPP.cpp ${SRCDIR}/UtilityFunctions.cpp ${SRCDIR}/AtomType.cpp ${SRCDIR}/Gene.cpp ${SRCDIR}/GeneInterval.cpp ${SRCDIR}/stringDB.cpp
OBJFILES = $(SRCFILES:.cpp=.o)

mfatoolkit: $(OBJFILES)
	if [ ! -d bin ]; then mkdir bin; fi
	${CC} ${CCFLAGS} -o bin/mfatoolkit $(^) ${LDFLAGS}

%.o: %.cpp
	${CC} ${CCFLAGS} -c $<; mv *.o ${SRCDIR}

deploy-mfatoolkit:
	if [ ! -d ${TARGET}/etc/MFAToolkit ]; then mkdir -p ${TARGET}/etc/MFAToolkit; fi
	cp -r etc ${TARGET}
	cp bin/mfatoolkit ${TARGET}/bin
	if [ ${IN_KBASE} ]; then curl "http://bioseed.mcs.anl.gov/~devoid/scip" > ${TARGET}/bin/scip; chmod +x ${TARGET}/bin/scip; fi

deploy: mfatoolkit deploy-mfatoolkit

clean:
	rm -f ${SRCDIR}/*.o bin/mfatoolkit
