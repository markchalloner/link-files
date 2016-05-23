# Link Files

This script manages the symlinking of user files from an another directory. By default files are symlinked to 

- ${HOME}/

from the folders

- ${HOME}/data/<hostname>/
- ${HOME}/.link-files/#all/

These folders can be changed using the options below.

The folder ${HOME}/.link-files can itself be a symlink to enable usage with a cloud provider (e.g. Dropbox)

## Usage

```
link-files.sh [options]

Options

  -h, --help                 optional: show this message
  -i, --install              optional: install the link-files
  -u, --uninstall            optional: uninstall the link-files
  -f, --from=FOLDER          optional: absolute path of from folder (not including /#all or /<hostname>)
  -t, --to=FOLDER            optional: absolute path of to folder
  -b, --behaviour=BEHAVIOUR  optional: which subfolder to use and fallback to. Can be 'host', 'hostorall', 'hostandall' (default), 'all'
                               host       - use only files from the host folder never the all folder
                               hostorall  - use files from the host folder if the folder exist otherwise the all folder
                               hostandall - use files from the host folder and the all folder if the file doesn't exist in the host folder
                               all        - use only files from the all folder never the host folder
  -c, --create               optional: create the link-files folder hierachy at --from or /Users/markchalloner/.link-files if not specified
  -o, --force                optional: links files even if there is one present. Will save current file as <filename>.bak.<YYYYMMDDHHMMSS>
  -d, --dryrun               optional: performs a dryrun
```

Generated with:

```
link-files.sh -r
```
