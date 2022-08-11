 function tests = $filename
            % Test suite for the file $funname.
            %
            %   Test suite for the file $funname
            %
            %   Example
            %   $filename
            %
            %   See also
            %     $funname
            
            % ------
            % Author: $author
            % e-mail: $mail
            [% Created: $date,    using Matlab  version]
            % Copyright $year $company.
            
            tests = functiontests(localfunctions);
            
            function test_Simple(testCase) %#ok<*DEFNU>
            % Test call of function without argument.
            $funname();
            value = 10;
            assertEqual(testCase, value, 10);
            
            