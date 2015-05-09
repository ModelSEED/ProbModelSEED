#BEGIN_HEADER
#END_HEADER


class ProbModelSEED:
    '''
    Module Name:
    ProbModelSEED

    Module Description:
    =head1 ProbModelSEED

=head2 DISTINCTIONS FROM KBASE
        All operations print their results in an output folder specified by the ouptut_loc argument.
        Functions are not as atomic. For example, model reconstruction will automatically create SBML and excel versions of model.
        Lists of essential genes will be automatically predicted. Lists of gapfilled reactions will be automatically printed into files.
        Combining workspace and ID arguments into single "ref" argument.
        Alot more output files, because not every output needs to be a typed object anymore.
        Thus functions create a folder full of output - not necessarily a single typed object.
    '''

    ######## WARNING FOR GEVENT USERS #######
    # Since asynchronous IO can lead to methods - even the same method -
    # interrupting each other, you must be *very* careful when using global
    # state. A method could easily clobber the state set by another while
    # the latter method is running.
    #########################################
    #BEGIN_CLASS_HEADER
    #END_CLASS_HEADER

    # config contains contents of config file in a hash or None if it couldn't
    # be found
    def __init__(self, config):
        #BEGIN_CONSTRUCTOR
        #END_CONSTRUCTOR
        pass

    def import_media(self, ctx, input):
        # ctx is the context object
        # return variables are: output
        #BEGIN import_media
        #END import_media

        # At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method import_media return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def reconstruct_fbamodel(self, ctx, input):
        # ctx is the context object
        # return variables are: output
        #BEGIN reconstruct_fbamodel
        #END reconstruct_fbamodel

        # At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method reconstruct_fbamodel return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def flux_balance_analysis(self, ctx, input):
        # ctx is the context object
        # return variables are: output
        #BEGIN flux_balance_analysis
        #END flux_balance_analysis

        # At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method flux_balance_analysis return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def gapfill_model(self, ctx, input):
        # ctx is the context object
        # return variables are: output
        #BEGIN gapfill_model
        #END gapfill_model

        # At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method gapfill_model return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]
