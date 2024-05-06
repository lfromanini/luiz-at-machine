# https://github.com/lfromanini/luiz-at-machine

# docker aliases and functions

alias dk=docker
alias dki="docker images"
alias dkrm="docker rm"
alias dkrmi="docker rmi"
alias dkps="docker ps --all"
alias dkprune="docker system prune --all --force"
alias dktop="docker stats"

function dkclean()
{
	docker rm $( docker ps --all --quiet --filter status=exited ) 2>/dev/null || true
	docker volume rm $( docker volume ls --quiet --filter dangling=true ) 2>/dev/null || true
}

function dklog() { docker logs "${1}" ; }
function dksh() { docker exec --interactive --tty ${@:2} "${1}" sh -c '$( which -a bash ash sh | head -n 1 )' ; }
function dksu() { dksh "${1}" ${@:2} --user root ; }
function dkstats() { docker ps --quiet --filter "name=${1}" | xargs docker stats --no-stream ; }

# kubernetes aliases and functions

[ -n "$BASH_VERSION" ] && source <( kubectl completion bash )
[ -n "$ZSH_VERSION" ] && source <( kubectl completion zsh )

alias k=kubectl

function konf()
{
	local returnCode=0
	local kubeConfigPath="$HOME/.kube/"
	local searchString="${1}"
	local fzfResult=""

	fzfResult=$( builtin cd "${kubeConfigPath}" && command find "${kubeConfigPath}" -maxdepth 1 -type f -iname '*'"${searchString}"'*' -printf "%f\n" | command sort | command fzf --exit-0 --select-1 --layout="reverse" --height=10 )
	returnCode=$?

	[ ${returnCode} -eq 0 ] && [ ! -z "${fzfResult}" ] && KUBECONFIG="${kubeConfigPath}${fzfResult}"

	[ -z "${KUBECONFIG}" ] && printf '\033[4m'"KUBECONFIG not set"'\033[0m'"\n" || printf "KUBECONFIG[ "'\033[1m'$( echo "${KUBECONFIG}" | command awk -F '/' '{ print $NF }' )'\033[0m'" ]\n"

	export KUBECONFIG

	[ ${returnCode} -eq 130 ] && returnCode=0
	return ${returnCode}
}

function kg()
{
	local returnCode=0
	local fzfPreview=$( whereis -b batcat bat cat | command awk '/: ./ { print $2 ; exit }' )
	local k8sMaster=$( { kubectl get nodes | command awk '/master/ { print $1 }' ; } 2>/dev/null )
	local fzfPrompt="  ${k8sMaster} > "

	if [[ "${fzfPreview}" == */bat* ]] ; then fzfPreview+=" --color=always --decorations=never --paging=never --language=yaml" ; fi

	kubectl get $* -o custom-columns="KIND:kind,NAMESPACE:metadata.namespace,NAME:metadata.name" | command fzf --exit-0 --layout="reverse" --height="100%" \
		--preview='kubectl get {1} {3} --namespace {2} -o yaml | '"${fzfPreview}" \
		--prompt="${fzfPrompt}" \
		--header=$'Press : reload[ CTRL + R ] or edit[ ENTER ]\n\n' \
		--header-lines=1 \
		--bind="ctrl-r:reload( kubectl get $* -o custom-columns=\"KIND:kind,NAMESPACE:metadata.namespace,NAME:metadata.name\" )" \
		--bind="enter:execute( kubectl edit {1} {3} --namespace {2} )"

	returnCode=$?
	[ ${returnCode} -eq 130 ] && returnCode=0
	return ${returnCode}
}

function kgpod()
{
	local returnCode=0
	local arg=""
	local k8sMaster=$( { kubectl get nodes | command awk '/master/ { print $1 }' ; } 2>/dev/null )
	local fzfPrompt="  ${k8sMaster} > "
	local fzfCmd="kubectl get pods --all-namespaces"
	local bIsNamespace="false"
	local bHasNamespace="false"
	local bAllNamespace="false"

	for arg in "$@" ; do
		case "${arg}" in
			-A|--all-namespaces)
				bAllNamespace="true"
			;;

			-n*|--namespace*)
				bHasNamespace="true"
			;;
		esac
	done

	# use default namespace if no namespace informed neither using all namespaces
	[ "${bHasNamespace}" = "false" ] && [ "${bAllNamespace}" = "false" ] && fzfCmd+=" --field-selector metadata.namespace=default"

	for arg in "$@" ; do
		case "${arg}" in
			-A|--all-namespaces)
			;;

			--namespace=*)
				fzfCmd+=" --field-selector metadata.namespace=""${arg#*=}"
				bIsNamespace="false"
			;;

			-n*|--namespace*)
				bIsNamespace="true"
			;;

			*)
				[ "${bIsNamespace}" = "true" ] && fzfCmd+=" --field-selector metadata.namespace=""${arg}"
				bIsNamespace="false"
			;;
		esac
	done

	for arg in "$@" ; do
		case "${arg}" in
			-A|--all-namespaces)
			;;

			--namespace=*)
				bIsNamespace="false"
			;;

			-n*|--namespace*)
				bIsNamespace="true"
			;;

			*)
				[ "${bIsNamespace}" = "false" ] && fzfCmd+=" | command grep --extended-regex \"NAME|${arg}\""	# NAME is used to keep header
				bIsNamespace="false"
			;;
		esac
	done

	sh -c "${fzfCmd}" | command fzf --exit-0 --layout="reverse" --height="100%" \
		--prompt="${fzfPrompt}" \
		--header=$'Press : reload[ CTRL + R ] or delete pod[ CTRL + D ]\n\n' \
		--header-lines=1 \
		--bind="ctrl-r:reload( ${fzfCmd} )" \
		--bind="ctrl-d:execute( kubectl delete pod --namespace {1} {2} )+reload( ${fzfCmd} )"

	returnCode=$?
	[ ${returnCode} -eq 130 ] && returnCode=0
	return ${returnCode}
}
