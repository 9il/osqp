classdef osqp < handle
    % osqp interface class for OSQP solver v0.0.0
    % This class provides a complete interface to the C implementation
    % of the OSQP solver.
    %
    % osqp Properties:
    %   objectHandle - pointer to the C structure of OSQP solver
    %
    % osqp Methods:
    %
    %   setup             - configure solver with problem data
    %   solve             - solve the QP
    %   update            - modify problem vectors
    %   warm_start        - set warm starting variables x and y
    %
    %   default_settings  - create default settings structure
    %   current_settings  - get the current solver settings structure
    %   update_settings   - update the current solver settings structure
    %
    %   get_dimensions    - get the number of variables and constraints
    %   version           - return OSQP version
    %   constant          - return a OSQP internal constant


    properties (SetAccess = private, Hidden = true)
        objectHandle % Handle to underlying C instance
    end
    methods
        %% Constructor - Create a new solver instance
        function this = osqp(varargin)
            % Construct OSQP solver class
            this.objectHandle = osqp_mex('new', varargin{:});
        end

        %% Destructor - destroy the solver instance
        function delete(this)
            % Destroy OSQP solver class
            osqp_mex('delete', this.objectHandle);
        end

        %%
        function out = version(this)
            % Return OSQP version
            out = osqp_mex('version', this.objectHandle);
        end

        %%
        function out = constant(this, constant_name)
            % CONSTANT Return solver constant
            %   C = CONSTANT(CONSTANT_NAME) return constant called CONSTANT_NAME
            out = osqp_mex('constant', this.objectHandle, constant_name);
        end

        %%
        function out = default_settings(this)
            % DEFAULT_SETTINGS get the default solver settings structure
           out = osqp_mex('default_settings', this.objectHandle);
        end

        %%
        function out = current_settings(this)
            % CURRENT_SETTINGS
            out = osqp_mex('current_settings', this.objectHandle);
        end

        %%
        function update_settings(this,varargin)
            % UPDATE_SETTINGS update the current solver settings structure

            %second input 'false' means that this is *not* a settings
            %initialization, so some parameter/values will be disallowed
            newSettings = validateSettings(this,false,varargin{:});

            %write the solver settings.  C-mex does not check input
            %data or protect against disallowed parameter modifications
            osqp_mex('update_settings', this.objectHandle, newSettings);

        end

        %%
        function [n,m]  = get_dimensions(this)
            % GET_DIMENSIONS get the number of variables and constraints

            [n,m] = osqp_mex('get_dimensions', this.objectHandle);

        end

        %%
        function update(this,varargin)
            % UPDATE modify the linear cost term and/or lower and upper bounds

            %second input 'false' means that this is *not* a settings
            %initialization, so some parameter/values will be disallowed
            allowedFields = {'q','l','u'};

            if(isempty(varargin))
                return;
            elseif(length(varargin) == 1)
                if(~isstruct(varargin{1}))
                    error('Single input should be a structure with new problem data');
                else
                    newData = varargin{1};
                end
            else % param / value style assumed
                newData = struct(varargin{:});
            end

            %check for unknown fields
            newFields = fieldnames(newData);
            badFieldsIdx = find(~ismember(newFields,allowedFields));
            if(~isempty(badFieldsIdx))
                 error('Unrecognized input field ''%s'' detected',newFields{badFieldsIdx(1)});
            end

            %get all of the terms.  Nonexistent fields will be passed
            %as empty mxArrays
            try q = double(full(newData.q(:))); catch q = []; end
            try l = double(full(newData.l(:))); catch l = []; end
            try u = double(full(newData.u(:))); catch u = []; end

            [n,m]  = get_dimensions(this);

            assert(isempty(q) || length(q) == n, 'input ''q'' is the wrong size');
            assert(isempty(l) || length(l) == m, 'input ''u'' is the wrong size');
            assert(isempty(u) || length(u) == m, 'input ''l'' is the wrong size');

            
            % Convert infinity values to OSQP_INFINITY
            if (~isempty(q))
                u = min(u, this.constant('OSQP_INFTY'));
            end
            if (~isempty(l))
                l = max(l, -this.constant('OSQP_INFTY'));
            end
            
            %write the new problem data.  C-mex does not protect
            %against unknown fields, but will handle empty values
            osqp_mex('update', this.objectHandle,q,l,u);

        end

        %%
        function varargout = setup(this, varargin)
            % SETUP configure solver with problem data
            %
            %   setup(P,q,A,l,u,options)

            nargin = length(varargin);

            %dimension checks on user data. Mex function does not
            %perform any checks on inputs, so check everything here
            assert(nargin >= 5, 'incorrect number of inputs');
            [P,q,A,l,u] = deal(varargin{1:5});

            %
            % Get problem dimensions
            %

            % Get number of variables n
            if (isempty(P))
                if (~isempty(q))
                    n = length(q);
                else
                    if (~isempty(A))
                        n = size(A, 2);
                    else
                        error('The problem does not have any variables');
                    end
                end
            else
                n = size(P, 1);
            end

            % Get number of constraints m
            if (isempty(A))
                m = 0;
            else
                m = size(A, 1);
            end

            %
            % Create sparse matrices and full vectors if they are empty
            %

            if (isempty(P))
                P = sparse(n, n);
            else
                P   = sparse(P);
            end
            if (isempty(q))
                q = zeros(n, 1);
            else
                q   = full(q(:));
            end

            % Create proper constraints if they are not passed
            if (isempty(A) && (~isempty(l) || ~isempty(u))) || ...
                (~isempty(A) && (isempty(l) && isempty(u)))
                error('A must be supplied together with at least one bound l or u');
            end

            if (~isempty(A) && isempty(l))
                l = -Inf(m, 1);
            end

            if (~isempty(A) && isempty(u))
                u = Inf(m, 1);
            end

            if (isempty(A))
                A = sparse(m, n);
                l = -Inf(m, 1);
                u = Inf(m, 1);
            else
                l  = full(l(:));
                u  = full(u(:));
                A = sparse(A);
            end


            %
            % Check vector dimensions (not checked from the C solver)
            %

            assert(length(q) == n, 'Incorrect dimension of q');
            assert(length(l) == m, 'Incorrect dimension of l');
            assert(length(u) == m, 'Incorrect dimension of u');

            %
            % Convert infinity values to OSQP_INFINITY
            %
            u = min(u, this.constant('OSQP_INFTY'));
            l = max(l, -this.constant('OSQP_INFTY'));


            %make a settings structure from the remainder of the arguments.
            %'true' means that this is a settings initialization, so all
            %parameter/values are allowed.  No extra inputs will result
            %in default settings being passed back
            theSettings = validateSettings(this,true,varargin{6:end});

            [varargout{1:nargout}] = osqp_mex('setup', this.objectHandle, n,m,P,q,A,l,u,theSettings);

        end


        %%

        function warm_start(this, varargin)
            % WARM_START warm start primal and/or dual variables
            %
            %   warm_start('x', x, 'y', y)
            %
            %   or warm_start('x', x)
            %   or warm_start('y', y)


            % Get problem dimensions
            [n, m]  = get_dimensions(this);

            % Get data
            allowedFields = {'x','y'};

            if(isempty(varargin))
                return;
            elseif(length(varargin) == 1)
                if(~isstruct(varargin{1}))
                    error('Single input should be a structure with new problem data');
                else
                    newData = varargin{1};
                end
            else % param / value style assumed
                newData = struct(varargin{:});
            end

            %check for unknown fields
            newFields = fieldnames(newData);
            badFieldsIdx = find(~ismember(newFields,allowedFields));
            if(~isempty(badFieldsIdx))
                 error('Unrecognized input field ''%s'' detected',newFields{badFieldsIdx(1)});
            end

            %get all of the terms.  Nonexistent fields will be passed
            %as empty mxArrays
            try x = double(full(newData.x(:))); catch x = []; end
            try y = double(full(newData.y(:))); catch y = []; end

            % Check dimensions
            assert(isempty(x) || length(x) == n, 'input ''x'' is the wrong size');
            assert(isempty(y) || length(y) == m, 'input ''y'' is the wrong size');


            % Decide which function to call
            if (~isempty(x) && isempty(y))
                osqp_mex('warm_start_x', this.objectHandle, x);
                return;
            end

            if (isempty(x) && ~isempty(y))
                osqp_mex('warm_start_y', this.objectHandle, y);
            end

            if (~isempty(x) && ~isempty(y))
                osqp_mex('warm_start', this.objectHandle, x, y);
            end

            if (isempty(x) && isempty(y))
                error('Unrecognized fields');
            end

        end

        %%
        function varargout = solve(this, varargin)
            % SOLVE solve the QP

            nargoutchk(0,1);  %either return nothing (but still solve), or a single output structure
            [out.x,out.y,out.info] = osqp_mex('solve', this.objectHandle);
            if(nargout)
                varargout{1} = out;
            end
            return;
        end

    end
end



function currentSettings = validateSettings(this,isInitialization,varargin)

%don't allow these fields to be changed
unmodifiableFields = {'rho','scaling','scaling_norm','scaling_iter'};

%get the current settings
if(isInitialization)
    currentSettings = osqp_mex('default_settings', this.objectHandle);
else
    currentSettings = osqp_mex('current_settings', this.objectHandle);
end

%no settings passed -> return defaults
if(isempty(varargin))
    return;
end

%check for structure style input
if(isstruct(varargin{1}))
    newSettings = varargin{1};
    assert(length(varargin) == 1, 'too many input arguments');
else
    newSettings = struct(varargin{:});
end

%get the osqp settings fields
currentFields = fieldnames(currentSettings);

%get the requested fields in the update
newFields = fieldnames(newSettings);

%check for unknown parameters
badFieldsIdx = find(~ismember(newFields,currentFields));
if(~isempty(badFieldsIdx))
    error('Unrecognized solver setting ''%s'' detected',newFields{badFieldsIdx(1)});
end

%check for disallowed fields if this in not an initialization call
if(~isInitialization)
    badFieldsIdx = find(ismember(newFields,unmodifiableFields));
    for i = badFieldsIdx(:)'
        if(~isequal(newSettings.(newFields{i}),currentSettings.(newFields{i})))
            error('Solver setting ''%s'' can only be changed at solver initialization.', newFields{i});
        end
    end
end

%check that everything is a nonnegative scalar
for i = 1:length(newFields)
    val = newSettings.(newFields{i});
    assert(isscalar(val) & isnumeric(val) & val >= 0, ...
        'Solver setting ''%s'' not specified as nonnegative scalar', newFields{i});
end

%everything checks out - merge the newSettings into the current ones
for i = 1:length(newFields)
    currentSettings.(newFields{i}) = double(newSettings.(newFields{i}));
end


end