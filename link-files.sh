#!/bin/bash
# Manages the symlinking of user files from per host folders

########################################
# Variables
########################################

host="$(hostname | tr '[:upper:]' '[:lower:]')"
date="$(date '+%Y%m%d%H%M%S')"
dir_data=".link-files"
dir_to_default="${HOME}"
dir_from_default="${dir_to_default}/${dir_data}"
dir_all_basename="#all"

########################################
# Usage
########################################

function usage() {
	cat <<-EOF

		This script manages the symlinking of user files from per host folders. By default files are symlinked to:

		- \${HOME}/

		from the folders:

		- \${HOME}/${dir_data}/\${HOSTNAME}/
		- \${HOME}/${dir_data}/#all/

		These folders can be changed using the options below.

		The folder \${HOME}/${dir_data}/ can itself be a symlink to enable usage with a cloud provider (e.g. Dropbox)
		
		Usage: $(basename ${0}) [options]
		
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
		  -c, --create               optional: create the link-files folder hierachy at --from or ${dir_from_default} if not specified
		  -o, --force                optional: links files even if there is one present. Will save current file as <filename>.bak.<YYYYMMDDHHMMSS>
		  -q, --quiet                optional: show no output
		  -d, --dryrun               optional: performs a dryrun

	EOF
	exit
}

function readme() {
	cat <<-EOF > $(dirname ${0})/README.md
		# Link Files
		$(source ${0} -h | sed 's/^Usage: /## Usage\'$'\n''\'$'\n''```\'$'\n''/')
		$(echo '```')
		
		## Install/Uninstall

		Use the included make file to install or uninstall

		Install:

		\`\`\`
		git clone https://github.com/markchalloner/link-files.git
		cd link-files
		sudo make install
		\`\`\`

		Uninstall:

		\`\`\`
		git clone https://github.com/markchalloner/link-files.git
		cd link-files
		sudo make uninstall
		\`\`\`

		## Readme

		Generated with:
		
		\`\`\`
		$(basename ${0}) -r
		\`\`\`
	EOF
	exit
}

########################################
# Execute
########################################

function execute() {
	if [ -z "${dryrun}" ]
	then
		local runner=eval
	else
		local runner=echo
	fi
	${runner} "${@}"
}

########################################
# Output
########################################

function output() {
	if [ -z "${quiet}" ]
        then
		echo "${@}"
	fi
}

########################################
# Helpers
########################################

function array_contains() {
	local i
	for i in "${1}"
	do 
		if [ "${i}" == "${2}" ]
		then
			return 0
		fi
	done
	return 1
}

# Takes a path and checks whether it has a trailing slash
function dir_trailing_slash_has() {
	local char=${1:(-1)} # Get last character
	if [ "${char}" == "/" ]
	then
		return 0
	fi
	return 1
}

# Takes a path and removes trailing slashes
function dir_trailing_slash_remove() {
	local dir="${1}"
	local i
	# Limit to 100 loops
	for i in {1..100}
	do
		if dir_trailing_slash_has "${dir}"
		then
			dir="${dir%?}"
		else
			break
		fi
	done
	output "${dir}"
}

########################################
# Functions
########################################

function do_create() {
	dir_from="${1}"
	dir_all="${2}"
	dir_host="${3}"
	mkdir -p "${dir_all}"
	mkdir -p "${dir_host}"
}

function do_install() {
	local behaviour="${1}"
	local dir_host="${2}"
	local dir_all="${3}"
	local names=
	local dirs=
	case "${behaviour}" in
		host)
			names=( "host" ) 
			dirs=( "${dir_host}" )
			;;
		hostorall|hostandall)
			names=( "host" "all" )
			dirs=( "${dir_host}" "${dir_all}" )
			;;
		all)
			names=( "host" )
			dirs=( "${dir_all}" )
			;;
	esac
	local files_done=()
	local i
	for i in "${!dirs[@]}"
	do
		local dir="${dirs[${i}]}"
		if [ -d "${dir}" ]
		then
			output "Linking files from ${names[${i}]} folder"
			local j
			for j in $(find ${dir} -mindepth 1 -not -name ".DS_Store")
			do
				local file="${j#${dir}/}"
				local from="${dir}/${file}"
				local to="${dir_to}/${file}"
				local parent_dir="$(basename "$(dirname "${file}")")"
				# If parent_dir is #copy or #hardlink then break
				if [ "${parent_dir}" == "#copy" -o "${parent_dir}" == "#hardlink" ]
				then
					continue
				fi
				# If we have already linked the file then continue
				if array_contains "${files_done}" "${file}"
				then
					continue
				fi
				local link
				if [ -d "${from}" ]
				then
					if [ ! -e "${to}" ]
					then
						output -e "\tCreating folder ${to}"
						execute mkdir -p "${to}"
					fi
					continue
				fi
				if [ -e "${to}" -a ! -L "${to}" ]
				then
					if [ -n "${force}" ]
					then
						to_bak="${to}.bak.${date}"
						output -e "\tThe file ${to} exists and is not a link, renaming to $(basename ${to_bak})"
						execute mv "${to}" "${to_bak}"
						link=1
					else 
						output -e "\tThe file ${to} exists and is not a link, skipping. Please review and link manually:\n\t\tln -s \"${from}\" \"${to}\""
						link=0
					fi
				else
					link=1
				fi
				if [ ${link} -eq 1 ]
				then
					# Probably safe to delete an existing symlink
					if [ -L "${to}" ]
					then
						execute rm "${to}"
					fi
					output -e "\tLinking from ${from} to ${to}"
					execute ln -s "${from}" "${to}"
					if [ $(basename "${from}") == "install.sh" ]
					then
						output -e "\t\tRunning ${to}"
						. ${to}
					fi
				fi
				files_done+=("${file}")
			done
			
			# Break if we have done the host and behaviour is hostorall
			if [ "${behaviour}" == "hostorall" ]
			then
				break
			fi
		else
			output "Unable to find ${dir}"
		fi
	done
}

function do_uninstall() {
	local behaviour="${1}"
	local dir_host="${2}"
	local dir_all="${3}"
	local names=
	local dirs=
	case "${behaviour}" in
		host)
			names=( "host" )
			dirs=( "${dir_host}" )
			;;
		hostorall|hostandall)
			names=( "host" "all" )
			dirs=( "${dir_host}" "${dir_all}" )
			;;
		all)
			names=( "host" )
			dirs=( "${dir_all}" )
			;;
	esac
	# Require a type and to be one of data, git, sites
	local files_done=()
	local i
	for i in "${!dirs[@]}"
	do
		local dir="${dirs[${i}]}" 
		if [ -d "${dir}" ]
		then
			output "Unlinking files from ${names[${i}]} folder"
			local j
			for j in $(find ${dir} -mindepth 1 -not -name ".DS_Store")
			do
				local file="${j#${dir}/}"
				local from="${dir}/${file}"
				local to="${dir_to}/${file}"
				# If we have already unlinked the file then continue
				if array_contains "${files_done}" "${file}"
				then
					continue
				fi
				if [ -d "${to}" ]
				then
					continue
				fi
				if [ -e "${to}" -a ! -L "${to}" ]
				then
					output -e "\tThe file ${to} exists and is not a link, skipping. Please review and remove manually:\n\t\trm ${to}"
				else
					# Probably safe to delete an existing symlink
					if [ -L "${to}" ]
					then
						output -e "\tUnlinking ${to} (${from})"
						if [ -d "${from}" ] && [ -f "${from}/uninstall.sh" ]
						then
							output -e "\t\tRunning ${to}/uninstall.sh"
							. ${to}/uninstall.sh
						fi
						execute rm "${to}"
					fi
				fi
				files_done+=("${file}")
			done
			
			# Break if we have done the host and behaviour is hostorall
			if [ "${behaviour}" == "hostorall" ]
			then
				break
			fi
		else
			output "Unable to find ${dir}"
		fi
	done	
}

########################################
# Run
########################################

# Set variables
dir_to="${dir_to_default}"
dir_from="${dir_from_default}"

while :
do
	case ${1} in
		-i|--install)
			install=1
			;;
		-u|--uninstall)
			uninstall=1
			;;
		-f|--from)
			dir_from="$(dir_trailing_slash_remove ${2})"
			shift
			;;
		-t|--to)
			dir_to="$(dir_trailing_slash_remove ${2})"
			shift
			;;
		-b|--behaviour)
			behaviour="${2}"
			shift
			;;
		-c|--create)
			create=1
			;;
		-o|--force)
			force=1
			;;
		-q|--quiet)
			quiet=1
			;;
		-d|--dryrun)
			dryrun=1
			;;
		-r|--readme)
			readme
			break 
			;;
		-h|--help)
			usage
			break
			;;
		--)
			break
			;;
		-?*)
			usage
			break
			;;
		*)
			break
			;;
	esac
	shift
done

# Check for action
[ -n "${create}" ] || [ -n "${install}" ] || [ -n "${uninstall}" ] || usage

# Set default behaviour
if [ -z "${behaviour}" ] && grep -q -v "^\(host\|host\(and\|or\)all\|all\)$" <<< "${behaviour}"
then
	behaviour="hostandall"
fi

# Dryrun option
if [ -n "${dryrun}" ]
then
	output "Dry run option activated. Commands will be logged instead of being run."
fi

# Set variables
dir_all="${dir_from}/${dir_all_basename}"
dir_host="${dir_from}/${host}"

if [ -n "${create}" ]
then
	output Creating...
	do_create "${dir_from}" "${dir_host}" "${dir_all}"
	output Done
fi

if [ -n "${install}" ]
then
	output Installing...
	do_install "${behaviour}" "${dir_host}" "${dir_all}"
	output Done
elif [ -n "${uninstall}" ]
then
	output Uninstalling...
	do_uninstall "${behaviour}" "${dir_host}" "${dir_all}"
	output Done
fi
