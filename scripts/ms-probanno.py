#! /usr/bin/env python

import argparse
import json
import sys
import os
import traceback
from biop3.ProbModelSEED.ProbAnnotationWorker import ProbAnnotationWorker
from biop3.Workspace.WorkspaceClient import Workspace, ServerError as WorkspaceServerError, _read_inifile

desc1 = '''
NAME
      ms-probanno -- run probabilistic annotation algorithm for a genome

SYNOPSIS
'''

desc2 = '''
DESCRIPTION
      Run the probabilistic algorithm for a genome.  The genomeref argument is
      the reference to the input genome object.  The rxnprobsref argument is
      the reference to where the output rxnprobs object is stored.
      
      The --ws-url optional argument specifies the url of the workspace service
      endpoint.  The --token optional argument specifies the authentication
      token for the user.
'''

desc3 = '''
EXAMPLES
      Run probabilistic annotation for Bacillus subtilis genome:
      > ms-probanno /mmundy/home/models/.224308.49_model/224308.49.genome /mmundy/home/models/.224308.49_model/224308.49.rxnprobs

AUTHORS
      Mike Mundy 
'''

if __name__ == '__main__':
    # Parse options.
    parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter, prog='ms-probanno', epilog=desc3)
    parser.add_argument('genomeref', help='reference to genome object', action='store', default=None)
    parser.add_argument('templateref', help='reference to template model object', action='store', default=None)
    parser.add_argument('rxnprobsref', help='reference to rxnprobs object', action='store', default=None)
    parser.add_argument('--ws-url', help='url of workspace service endpoint', action='store', dest='wsURL', default='https://p3.theseed.org/services/Workspace')
    parser.add_argument('--token', help='token for user', action='store', dest='token', default=None)
    usage = parser.format_usage()
    parser.description = desc1 + '      ' + usage + desc2
    parser.usage = argparse.SUPPRESS
    args = parser.parse_args()
    
    # Get the token from the config file if one is not provided.
    if args.token is None:
        authdata = _read_inifile()
        args.token = authdata['token']
     
    # Workaround for extraneous delimiter tacked on the end of references.
    if args.genomeref[-2:] == '||':
        args.genomeref = args.genomeref[:-2]
    if args.templateref[-2:] == '||':
        args.templateref = args.templateref[:-2]
    
    # Get the genome object from the workspace (for the features).
    wsClient = Workspace(url=args.wsURL, token=args.token)
    try:
        # The get() method returns an array of tuples where the first element is
        # the object's metadata (which is valid json) and the second element is
        # the object's data (which is not valid json).
        object = wsClient.get({ 'objects': [ args.genomeref ] })
        genome = json.loads(object[0][1])

    except WorkspaceServerError as e:
        sys.stderr.write('Failed to get genome using reference %s\n' %(args.genomeref))
        exit(1)

    # Get the template object from the workspace (for the complexes and roles).
    try:
        # See comment above on output of get() method.
        object = wsClient.get({ 'objects': [ args.templateref ] })
        template = json.loads(object[0][1])
        
    except WorkspaceServerError as e:
        sys.stderr.write('Failed to get template model using reference %s\n' %(args.templateref))
        exit(1)

    # Build a dictionary to look up roles in the template by ID.
    roles = dict()
    for index in range(len(template['roles'])):        
        roles[template['roles'][index]['id']] = index

    # Create a dictionary to map a complex to a list of roles as defined in the template.
    complexesToRoles = dict()
    for index in range(len(template['complexes'])):
        complexId = template['complexes'][index]['id']
        complexesToRoles[complexId] = list()
        for crindex in range(len(template['complexes'][index]['complexroles'])):
            # A complex has a list of complexroles and each complexrole has a reference
            # to a role and each role has a name. Role ID is last element in reference.
            roleId = template['complexes'][index]['complexroles'][crindex]['templaterole_ref'].split('/')[-1]
            complexesToRoles[complexId].append(template['roles'][roles[roleId]]['name'])        

    # Create a dictionary to map a reaction to a list of complexes as defined in the template.
    reactionsToComplexes = dict()
    for index in range(len(template['reactions'])):
        reactionId = template['reactions'][index]['id']
        reactionsToComplexes[reactionId] = list()
        for complexRef in template['reactions'][index]['templatecomplex_refs']:
            # Complex ID is last element in reference.
            reactionsToComplexes[reactionId].append(complexRef.split('/')[-1])

    # Create a worker for running the algorithm.
    worker = ProbAnnotationWorker(genome['id'])
        
    # Run the probabilistic annotation algorithm.
    try:
        # Convert the features in the genome object to a fasta file.
        fastaFile = worker.genomeToFasta(genome['features'])
        
        # Run blast using the fasta file.
        blastResultFile = worker.runBlast(fastaFile)
        
        # Calculate roleset probabilities.
        rolestringTuples = worker.rolesetProbabilitiesMarble(blastResultFile)
        
        # Calculate per-gene role probabilities.
        roleProbs = worker.rolesetProbabilitiesToRoleProbabilities(rolestringTuples)
        
        # Calculate whole cell role probabilities.
        totalRoleProbs = worker.totalRoleProbabilities(roleProbs)

        # Calculate complex probabilities.
        complexProbs = worker.complexProbabilities(totalRoleProbs, complexesToRequiredRoles = complexesToRoles)
 
        # Calculate reaction probabilities.
        reactionProbs = worker.reactionProbabilities(complexProbs, rxnsToComplexes = reactionsToComplexes) 

        # Cleanup work directory.
        worker.cleanup()
        
    except Exception as e:
        worker.cleanup()
        sys.stderr.write('Failed to run probabilistic annotation algorithm: %s\n' %(e.message))
        tb = traceback.format_exc()
        sys.stderr.write(tb)
        exit(1)

    # Create the rxnprobs object in the workspace.
    try:
        data = dict()
        data['reaction_probabilities'] = reactionProbs
        input = dict()
        input['objects'] = list()
        input['overwrite'] = 1
        input['objects'].append( [ args.rxnprobsref, 'rxnprobs', { }, data ]) # 'rxnprobs' when workspace is updated
        wsClient.create(input)

    except WorkspaceServerError as e:
        sys.stderr.write('Failed to create rxnprobs object using reference %s\n' %(args.rxnprobsref))
        tb = traceback.format_exc()
        sys.stderr.write(tb)
        exit(1)

    exit(0)