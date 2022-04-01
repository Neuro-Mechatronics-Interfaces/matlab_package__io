# +io #
Matlab package for input/output conventional consistency.

## Install ##
Once this has been added as a submodule to a given repository, you can then run io.setup to install other required repos:  
(From the command window)  
```(matlab)
io.setup;
```
You should be in the repository folder that is the parent repo of this submodule, which should be added as a MATLAB package (i.e. with the leading `+` in the name of the submodule folder). For example, add it to your repository as:  
```(matlab)
git submodule add git@github.com:m053m716/-io.git +io
```
This will add the folder with the correct package name.