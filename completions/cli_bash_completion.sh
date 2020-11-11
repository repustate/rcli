# bash completion for cli                                  -*- shell-script -*-

__cli_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__cli_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__cli_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__cli_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__cli_handle_go_custom_completion()
{
    __cli_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly cli allows to handle aliases
    args=("${words[@]:1}")
    requestComp="${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __cli_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __cli_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __cli_debug "${FUNCNAME[0]}: calling ${requestComp}"
    # Use eval to handle any environment variables and such
    out=$(eval "${requestComp}" 2>/dev/null)

    # Extract the directive integer at the very end of the output following a colon (:)
    directive=${out##*:}
    # Remove the directive
    out=${out%:*}
    if [ "${directive}" = "${out}" ]; then
        # There is not directive specified
        directive=0
    fi
    __cli_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __cli_debug "${FUNCNAME[0]}: the completions are: ${out[*]}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        # Error code.  No completion.
        __cli_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __cli_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __cli_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local fullFilter filter filteringCmd
        # Do not use quotes around the $out variable or else newline
        # characters will be kept.
        for filter in ${out[*]}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __cli_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subDir
        # Use printf to strip any trailing newline
        subdir=$(printf "%s" "${out[0]}")
        if [ -n "$subdir" ]; then
            __cli_debug "Listing directories in $subdir"
            __cli_handle_subdirs_in_dir_flag "$subdir"
        else
            __cli_debug "Listing directories in ."
            _filedir -d
        fi
    else
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out[*]}" -- "$cur")
    fi
}

__cli_handle_reply()
{
    __cli_debug "${FUNCNAME[0]}"
    local comp
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            while IFS='' read -r comp; do
                COMPREPLY+=("$comp")
            done < <(compgen -W "${allflags[*]}" -- "$cur")
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __cli_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi
            return 0;
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __cli_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions+=("${must_have_one_noun[@]}")
    elif [[ -n "${has_completion_function}" ]]; then
        # if a go completion function is provided, defer to that function
        __cli_handle_go_custom_completion
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    while IFS='' read -r comp; do
        COMPREPLY+=("$comp")
    done < <(compgen -W "${completions[*]}" -- "$cur")

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
		if declare -F __cli_custom_func >/dev/null; then
			# try command name qualified custom func
			__cli_custom_func
		else
			# otherwise fall back to unqualified for compatibility
			declare -F __custom_func >/dev/null && __custom_func
		fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__cli_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__cli_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__cli_handle_flag()
{
    __cli_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __cli_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __cli_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __cli_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __cli_contains_word "${words[c]}" "${two_word_flags[@]}"; then
			  __cli_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__cli_handle_noun()
{
    __cli_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __cli_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __cli_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__cli_handle_command()
{
    __cli_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_cli_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __cli_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__cli_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __cli_handle_reply
        return
    fi
    __cli_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __cli_handle_flag
    elif __cli_contains_word "${words[c]}" "${commands[@]}"; then
        __cli_handle_command
    elif [[ $c -eq 0 ]]; then
        __cli_handle_command
    elif __cli_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __cli_handle_command
        else
            __cli_handle_noun
        fi
    else
        __cli_handle_noun
    fi
    __cli_handle_word
}

_cli_index()
{
    last_command="cli_index"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--file=")
    two_word_flags+=("--file")
    flags_with_completion+=("--file")
    flags_completion+=("_filedir")
    two_word_flags+=("-f")
    flags_with_completion+=("-f")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--file")
    local_nonpersistent_flags+=("--file=")
    local_nonpersistent_flags+=("-f")
    flags+=("--lang=")
    two_word_flags+=("--lang")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--lang")
    local_nonpersistent_flags+=("--lang=")
    local_nonpersistent_flags+=("-l")
    flags+=("--text=")
    two_word_flags+=("--text")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--text")
    local_nonpersistent_flags+=("--text=")
    local_nonpersistent_flags+=("-t")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cli_search()
{
    last_command="cli_search"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--list-terms")
    local_nonpersistent_flags+=("--list-terms")

    must_have_one_flag=()
    must_have_one_noun=()
    must_have_one_noun+=("Animal.amphibian")
    must_have_one_noun+=("Animal.amphibian")
    must_have_one_noun+=("Animal.amphibian")
    must_have_one_noun+=("Animal.bird")
    must_have_one_noun+=("Animal.bird")
    must_have_one_noun+=("Animal.bird")
    must_have_one_noun+=("Animal.dog")
    must_have_one_noun+=("Animal.dog")
    must_have_one_noun+=("Animal.dog")
    must_have_one_noun+=("Animal.fish")
    must_have_one_noun+=("Animal.fish")
    must_have_one_noun+=("Animal.fish")
    must_have_one_noun+=("Animal.insect")
    must_have_one_noun+=("Animal.insect")
    must_have_one_noun+=("Animal.insect")
    must_have_one_noun+=("Animal.mammal")
    must_have_one_noun+=("Animal.mammal")
    must_have_one_noun+=("Animal.mammal")
    must_have_one_noun+=("Animal.racehorse")
    must_have_one_noun+=("Animal.racehorse")
    must_have_one_noun+=("Animal.racehorse")
    must_have_one_noun+=("Animal.reptile")
    must_have_one_noun+=("Animal.reptile")
    must_have_one_noun+=("Animal.reptile")
    must_have_one_noun+=("Event.activity")
    must_have_one_noun+=("Event.activity")
    must_have_one_noun+=("Event.activity")
    must_have_one_noun+=("Event.airplane_crash")
    must_have_one_noun+=("Event.airplane_crash")
    must_have_one_noun+=("Event.airplane_crash")
    must_have_one_noun+=("Event.award")
    must_have_one_noun+=("Event.award")
    must_have_one_noun+=("Event.award")
    must_have_one_noun+=("Event.coup")
    must_have_one_noun+=("Event.coup")
    must_have_one_noun+=("Event.coup")
    must_have_one_noun+=("Event.crime")
    must_have_one_noun+=("Event.crime")
    must_have_one_noun+=("Event.crime")
    must_have_one_noun+=("Event.festival")
    must_have_one_noun+=("Event.festival")
    must_have_one_noun+=("Event.festival")
    must_have_one_noun+=("Event.financial")
    must_have_one_noun+=("Event.financial")
    must_have_one_noun+=("Event.financial")
    must_have_one_noun+=("Event.genocide")
    must_have_one_noun+=("Event.genocide")
    must_have_one_noun+=("Event.genocide")
    must_have_one_noun+=("Event.legal")
    must_have_one_noun+=("Event.legal")
    must_have_one_noun+=("Event.legal")
    must_have_one_noun+=("Event.legislation")
    must_have_one_noun+=("Event.legislation")
    must_have_one_noun+=("Event.legislation")
    must_have_one_noun+=("Event.massacre")
    must_have_one_noun+=("Event.massacre")
    must_have_one_noun+=("Event.massacre")
    must_have_one_noun+=("Event.military_operation")
    must_have_one_noun+=("Event.military_operation")
    must_have_one_noun+=("Event.military_operation")
    must_have_one_noun+=("Event.motor_race")
    must_have_one_noun+=("Event.motor_race")
    must_have_one_noun+=("Event.motor_race")
    must_have_one_noun+=("Event.pandemic")
    must_have_one_noun+=("Event.pandemic")
    must_have_one_noun+=("Event.pandemic")
    must_have_one_noun+=("Event.political")
    must_have_one_noun+=("Event.political")
    must_have_one_noun+=("Event.political")
    must_have_one_noun+=("Event.religion")
    must_have_one_noun+=("Event.religion")
    must_have_one_noun+=("Event.religion")
    must_have_one_noun+=("Event.social")
    must_have_one_noun+=("Event.social")
    must_have_one_noun+=("Event.social")
    must_have_one_noun+=("Event.space_mission")
    must_have_one_noun+=("Event.space_mission")
    must_have_one_noun+=("Event.space_mission")
    must_have_one_noun+=("Event.sport")
    must_have_one_noun+=("Event.sport")
    must_have_one_noun+=("Event.sport")
    must_have_one_noun+=("Event.sporting_event")
    must_have_one_noun+=("Event.sporting_event")
    must_have_one_noun+=("Event.sporting_event")
    must_have_one_noun+=("Event.sports_action")
    must_have_one_noun+=("Event.sports_action")
    must_have_one_noun+=("Event.sports_action")
    must_have_one_noun+=("Event.terrorist_attack")
    must_have_one_noun+=("Event.terrorist_attack")
    must_have_one_noun+=("Event.terrorist_attack")
    must_have_one_noun+=("Event.time_management")
    must_have_one_noun+=("Event.time_management")
    must_have_one_noun+=("Event.time_management")
    must_have_one_noun+=("Event.trade_show")
    must_have_one_noun+=("Event.trade_show")
    must_have_one_noun+=("Event.trade_show")
    must_have_one_noun+=("Event.trial")
    must_have_one_noun+=("Event.trial")
    must_have_one_noun+=("Event.trial")
    must_have_one_noun+=("Event.us_constitution")
    must_have_one_noun+=("Event.us_constitution")
    must_have_one_noun+=("Event.us_constitution")
    must_have_one_noun+=("Event.war")
    must_have_one_noun+=("Event.war")
    must_have_one_noun+=("Event.war")
    must_have_one_noun+=("Event.weather")
    must_have_one_noun+=("Event.weather")
    must_have_one_noun+=("Event.weather")
    must_have_one_noun+=("Health.alternative_medicine")
    must_have_one_noun+=("Health.alternative_medicine")
    must_have_one_noun+=("Health.alternative_medicine")
    must_have_one_noun+=("Health.antibody")
    must_have_one_noun+=("Health.antibody")
    must_have_one_noun+=("Health.antibody")
    must_have_one_noun+=("Health.antigen")
    must_have_one_noun+=("Health.antigen")
    must_have_one_noun+=("Health.antigen")
    must_have_one_noun+=("Health.artery")
    must_have_one_noun+=("Health.artery")
    must_have_one_noun+=("Health.artery")
    must_have_one_noun+=("Health.body_part")
    must_have_one_noun+=("Health.body_part")
    must_have_one_noun+=("Health.body_part")
    must_have_one_noun+=("Health.bone")
    must_have_one_noun+=("Health.bone")
    must_have_one_noun+=("Health.bone")
    must_have_one_noun+=("Health.cancer")
    must_have_one_noun+=("Health.cancer")
    must_have_one_noun+=("Health.cancer")
    must_have_one_noun+=("Health.cell")
    must_have_one_noun+=("Health.cell")
    must_have_one_noun+=("Health.cell")
    must_have_one_noun+=("Health.condition")
    must_have_one_noun+=("Health.condition")
    must_have_one_noun+=("Health.condition")
    must_have_one_noun+=("Health.diet")
    must_have_one_noun+=("Health.diet")
    must_have_one_noun+=("Health.diet")
    must_have_one_noun+=("Health.disorder")
    must_have_one_noun+=("Health.disorder")
    must_have_one_noun+=("Health.disorder")
    must_have_one_noun+=("Health.enzyme")
    must_have_one_noun+=("Health.enzyme")
    must_have_one_noun+=("Health.enzyme")
    must_have_one_noun+=("Health.gene")
    must_have_one_noun+=("Health.gene")
    must_have_one_noun+=("Health.gene")
    must_have_one_noun+=("Health.hormone")
    must_have_one_noun+=("Health.hormone")
    must_have_one_noun+=("Health.hormone")
    must_have_one_noun+=("Health.muscle")
    must_have_one_noun+=("Health.muscle")
    must_have_one_noun+=("Health.muscle")
    must_have_one_noun+=("Health.organ")
    must_have_one_noun+=("Health.organ")
    must_have_one_noun+=("Health.organ")
    must_have_one_noun+=("Health.peptide")
    must_have_one_noun+=("Health.peptide")
    must_have_one_noun+=("Health.peptide")
    must_have_one_noun+=("Health.pharmaceutical")
    must_have_one_noun+=("Health.pharmaceutical")
    must_have_one_noun+=("Health.pharmaceutical")
    must_have_one_noun+=("Health.rate")
    must_have_one_noun+=("Health.rate")
    must_have_one_noun+=("Health.rate")
    must_have_one_noun+=("Health.recreational_drug")
    must_have_one_noun+=("Health.recreational_drug")
    must_have_one_noun+=("Health.recreational_drug")
    must_have_one_noun+=("Health.surgery")
    must_have_one_noun+=("Health.surgery")
    must_have_one_noun+=("Health.surgery")
    must_have_one_noun+=("Health.symptom")
    must_have_one_noun+=("Health.symptom")
    must_have_one_noun+=("Health.symptom")
    must_have_one_noun+=("Health.tests")
    must_have_one_noun+=("Health.tests")
    must_have_one_noun+=("Health.tests")
    must_have_one_noun+=("Health.treatment")
    must_have_one_noun+=("Health.treatment")
    must_have_one_noun+=("Health.treatment")
    must_have_one_noun+=("Health.trial")
    must_have_one_noun+=("Health.trial")
    must_have_one_noun+=("Health.trial")
    must_have_one_noun+=("Health.virus")
    must_have_one_noun+=("Health.virus")
    must_have_one_noun+=("Health.virus")
    must_have_one_noun+=("Health.vitamin")
    must_have_one_noun+=("Health.vitamin")
    must_have_one_noun+=("Health.vitamin")
    must_have_one_noun+=("Location.academy")
    must_have_one_noun+=("Location.academy")
    must_have_one_noun+=("Location.academy")
    must_have_one_noun+=("Location.airport")
    must_have_one_noun+=("Location.airport")
    must_have_one_noun+=("Location.airport")
    must_have_one_noun+=("Location.borough")
    must_have_one_noun+=("Location.borough")
    must_have_one_noun+=("Location.borough")
    must_have_one_noun+=("Location.bridge")
    must_have_one_noun+=("Location.bridge")
    must_have_one_noun+=("Location.bridge")
    must_have_one_noun+=("Location.building")
    must_have_one_noun+=("Location.building")
    must_have_one_noun+=("Location.building")
    must_have_one_noun+=("Location.canyon")
    must_have_one_noun+=("Location.canyon")
    must_have_one_noun+=("Location.canyon")
    must_have_one_noun+=("Location.city")
    must_have_one_noun+=("Location.city")
    must_have_one_noun+=("Location.city")
    must_have_one_noun+=("Location.city_area")
    must_have_one_noun+=("Location.city_area")
    must_have_one_noun+=("Location.city_area")
    must_have_one_noun+=("Location.continent")
    must_have_one_noun+=("Location.continent")
    must_have_one_noun+=("Location.continent")
    must_have_one_noun+=("Location.convention_centre")
    must_have_one_noun+=("Location.convention_centre")
    must_have_one_noun+=("Location.convention_centre")
    must_have_one_noun+=("Location.country")
    must_have_one_noun+=("Location.country")
    must_have_one_noun+=("Location.country")
    must_have_one_noun+=("Location.county")
    must_have_one_noun+=("Location.county")
    must_have_one_noun+=("Location.county")
    must_have_one_noun+=("Location.desert")
    must_have_one_noun+=("Location.desert")
    must_have_one_noun+=("Location.desert")
    must_have_one_noun+=("Location.direction")
    must_have_one_noun+=("Location.direction")
    must_have_one_noun+=("Location.direction")
    must_have_one_noun+=("Location.forest")
    must_have_one_noun+=("Location.forest")
    must_have_one_noun+=("Location.forest")
    must_have_one_noun+=("Location.government_residence")
    must_have_one_noun+=("Location.government_residence")
    must_have_one_noun+=("Location.government_residence")
    must_have_one_noun+=("Location.high_school")
    must_have_one_noun+=("Location.high_school")
    must_have_one_noun+=("Location.high_school")
    must_have_one_noun+=("Location.highway")
    must_have_one_noun+=("Location.highway")
    must_have_one_noun+=("Location.highway")
    must_have_one_noun+=("Location.hotel")
    must_have_one_noun+=("Location.hotel")
    must_have_one_noun+=("Location.hotel")
    must_have_one_noun+=("Location.island")
    must_have_one_noun+=("Location.island")
    must_have_one_noun+=("Location.island")
    must_have_one_noun+=("Location.lake")
    must_have_one_noun+=("Location.lake")
    must_have_one_noun+=("Location.lake")
    must_have_one_noun+=("Location.market")
    must_have_one_noun+=("Location.market")
    must_have_one_noun+=("Location.market")
    must_have_one_noun+=("Location.military_base")
    must_have_one_noun+=("Location.military_base")
    must_have_one_noun+=("Location.military_base")
    must_have_one_noun+=("Location.mountain")
    must_have_one_noun+=("Location.mountain")
    must_have_one_noun+=("Location.mountain")
    must_have_one_noun+=("Location.mountain_range")
    must_have_one_noun+=("Location.mountain_range")
    must_have_one_noun+=("Location.mountain_range")
    must_have_one_noun+=("Location.museum_or_gallery")
    must_have_one_noun+=("Location.museum_or_gallery")
    must_have_one_noun+=("Location.museum_or_gallery")
    must_have_one_noun+=("Location.neighborhood")
    must_have_one_noun+=("Location.neighborhood")
    must_have_one_noun+=("Location.neighborhood")
    must_have_one_noun+=("Location.nightclub")
    must_have_one_noun+=("Location.nightclub")
    must_have_one_noun+=("Location.nightclub")
    must_have_one_noun+=("Location.ocean")
    must_have_one_noun+=("Location.ocean")
    must_have_one_noun+=("Location.ocean")
    must_have_one_noun+=("Location.park")
    must_have_one_noun+=("Location.park")
    must_have_one_noun+=("Location.park")
    must_have_one_noun+=("Location.power_station")
    must_have_one_noun+=("Location.power_station")
    must_have_one_noun+=("Location.power_station")
    must_have_one_noun+=("Location.prison")
    must_have_one_noun+=("Location.prison")
    must_have_one_noun+=("Location.prison")
    must_have_one_noun+=("Location.public_space")
    must_have_one_noun+=("Location.public_space")
    must_have_one_noun+=("Location.public_space")
    must_have_one_noun+=("Location.region")
    must_have_one_noun+=("Location.region")
    must_have_one_noun+=("Location.region")
    must_have_one_noun+=("Location.religious_site")
    must_have_one_noun+=("Location.religious_site")
    must_have_one_noun+=("Location.religious_site")
    must_have_one_noun+=("Location.river")
    must_have_one_noun+=("Location.river")
    must_have_one_noun+=("Location.river")
    must_have_one_noun+=("Location.sea")
    must_have_one_noun+=("Location.sea")
    must_have_one_noun+=("Location.sea")
    must_have_one_noun+=("Location.stadium")
    must_have_one_noun+=("Location.stadium")
    must_have_one_noun+=("Location.stadium")
    must_have_one_noun+=("Location.state_or_province")
    must_have_one_noun+=("Location.state_or_province")
    must_have_one_noun+=("Location.state_or_province")
    must_have_one_noun+=("Location.statue")
    must_have_one_noun+=("Location.statue")
    must_have_one_noun+=("Location.statue")
    must_have_one_noun+=("Location.street")
    must_have_one_noun+=("Location.street")
    must_have_one_noun+=("Location.street")
    must_have_one_noun+=("Location.train_station")
    must_have_one_noun+=("Location.train_station")
    must_have_one_noun+=("Location.train_station")
    must_have_one_noun+=("Location.transit_line")
    must_have_one_noun+=("Location.transit_line")
    must_have_one_noun+=("Location.transit_line")
    must_have_one_noun+=("Location.university")
    must_have_one_noun+=("Location.university")
    must_have_one_noun+=("Location.university")
    must_have_one_noun+=("Location.ward")
    must_have_one_noun+=("Location.ward")
    must_have_one_noun+=("Location.ward")
    must_have_one_noun+=("Location.waterfall")
    must_have_one_noun+=("Location.waterfall")
    must_have_one_noun+=("Location.waterfall")
    must_have_one_noun+=("Number.distribution")
    must_have_one_noun+=("Number.distribution")
    must_have_one_noun+=("Number.distribution")
    must_have_one_noun+=("Number.economics")
    must_have_one_noun+=("Number.economics")
    must_have_one_noun+=("Number.economics")
    must_have_one_noun+=("Number.financials")
    must_have_one_noun+=("Number.financials")
    must_have_one_noun+=("Number.financials")
    must_have_one_noun+=("Number.math_constant")
    must_have_one_noun+=("Number.math_constant")
    must_have_one_noun+=("Number.math_constant")
    must_have_one_noun+=("Number.number")
    must_have_one_noun+=("Number.number")
    must_have_one_noun+=("Number.number")
    must_have_one_noun+=("Number.pricing")
    must_have_one_noun+=("Number.pricing")
    must_have_one_noun+=("Number.pricing")
    must_have_one_noun+=("Number.system")
    must_have_one_noun+=("Number.system")
    must_have_one_noun+=("Number.system")
    must_have_one_noun+=("Number.taxes")
    must_have_one_noun+=("Number.taxes")
    must_have_one_noun+=("Number.taxes")
    must_have_one_noun+=("Org.broadcaster")
    must_have_one_noun+=("Org.broadcaster")
    must_have_one_noun+=("Org.broadcaster")
    must_have_one_noun+=("Org.business")
    must_have_one_noun+=("Org.business")
    must_have_one_noun+=("Org.business")
    must_have_one_noun+=("Org.central_bank")
    must_have_one_noun+=("Org.central_bank")
    must_have_one_noun+=("Org.central_bank")
    must_have_one_noun+=("Org.college_sports_team")
    must_have_one_noun+=("Org.college_sports_team")
    must_have_one_noun+=("Org.college_sports_team")
    must_have_one_noun+=("Org.court")
    must_have_one_noun+=("Org.court")
    must_have_one_noun+=("Org.court")
    must_have_one_noun+=("Org.empire")
    must_have_one_noun+=("Org.empire")
    must_have_one_noun+=("Org.empire")
    must_have_one_noun+=("Org.fraternity_sorority")
    must_have_one_noun+=("Org.fraternity_sorority")
    must_have_one_noun+=("Org.fraternity_sorority")
    must_have_one_noun+=("Org.government")
    must_have_one_noun+=("Org.government")
    must_have_one_noun+=("Org.government")
    must_have_one_noun+=("Org.government_agency")
    must_have_one_noun+=("Org.government_agency")
    must_have_one_noun+=("Org.government_agency")
    must_have_one_noun+=("Org.government_committee")
    must_have_one_noun+=("Org.government_committee")
    must_have_one_noun+=("Org.government_committee")
    must_have_one_noun+=("Org.government_legislature")
    must_have_one_noun+=("Org.government_legislature")
    must_have_one_noun+=("Org.government_legislature")
    must_have_one_noun+=("Org.government_program")
    must_have_one_noun+=("Org.government_program")
    must_have_one_noun+=("Org.government_program")
    must_have_one_noun+=("Org.hackers")
    must_have_one_noun+=("Org.hackers")
    must_have_one_noun+=("Org.hackers")
    must_have_one_noun+=("Org.hospital")
    must_have_one_noun+=("Org.hospital")
    must_have_one_noun+=("Org.hospital")
    must_have_one_noun+=("Org.ideology")
    must_have_one_noun+=("Org.ideology")
    must_have_one_noun+=("Org.ideology")
    must_have_one_noun+=("Org.institute")
    must_have_one_noun+=("Org.institute")
    must_have_one_noun+=("Org.institute")
    must_have_one_noun+=("Org.intelligence_agency")
    must_have_one_noun+=("Org.intelligence_agency")
    must_have_one_noun+=("Org.intelligence_agency")
    must_have_one_noun+=("Org.junior_hockey_team")
    must_have_one_noun+=("Org.junior_hockey_team")
    must_have_one_noun+=("Org.junior_hockey_team")
    must_have_one_noun+=("Org.labor_union")
    must_have_one_noun+=("Org.labor_union")
    must_have_one_noun+=("Org.labor_union")
    must_have_one_noun+=("Org.law_enforcement")
    must_have_one_noun+=("Org.law_enforcement")
    must_have_one_noun+=("Org.law_enforcement")
    must_have_one_noun+=("Org.medical")
    must_have_one_noun+=("Org.medical")
    must_have_one_noun+=("Org.medical")
    must_have_one_noun+=("Org.militants")
    must_have_one_noun+=("Org.militants")
    must_have_one_noun+=("Org.militants")
    must_have_one_noun+=("Org.military")
    must_have_one_noun+=("Org.military")
    must_have_one_noun+=("Org.military")
    must_have_one_noun+=("Org.minor_league_baseball_team")
    must_have_one_noun+=("Org.minor_league_baseball_team")
    must_have_one_noun+=("Org.minor_league_baseball_team")
    must_have_one_noun+=("Org.music_group")
    must_have_one_noun+=("Org.music_group")
    must_have_one_noun+=("Org.music_group")
    must_have_one_noun+=("Org.news_agency")
    must_have_one_noun+=("Org.news_agency")
    must_have_one_noun+=("Org.news_agency")
    must_have_one_noun+=("Org.newspaper")
    must_have_one_noun+=("Org.newspaper")
    must_have_one_noun+=("Org.newspaper")
    must_have_one_noun+=("Org.nonprofit")
    must_have_one_noun+=("Org.nonprofit")
    must_have_one_noun+=("Org.nonprofit")
    must_have_one_noun+=("Org.online_news")
    must_have_one_noun+=("Org.online_news")
    must_have_one_noun+=("Org.online_news")
    must_have_one_noun+=("Org.political_movement")
    must_have_one_noun+=("Org.political_movement")
    must_have_one_noun+=("Org.political_movement")
    must_have_one_noun+=("Org.political_party")
    must_have_one_noun+=("Org.political_party")
    must_have_one_noun+=("Org.political_party")
    must_have_one_noun+=("Org.pro_baseball_team")
    must_have_one_noun+=("Org.pro_baseball_team")
    must_have_one_noun+=("Org.pro_baseball_team")
    must_have_one_noun+=("Org.pro_basketball_team")
    must_have_one_noun+=("Org.pro_basketball_team")
    must_have_one_noun+=("Org.pro_basketball_team")
    must_have_one_noun+=("Org.pro_football_team")
    must_have_one_noun+=("Org.pro_football_team")
    must_have_one_noun+=("Org.pro_football_team")
    must_have_one_noun+=("Org.pro_hockey_team")
    must_have_one_noun+=("Org.pro_hockey_team")
    must_have_one_noun+=("Org.pro_hockey_team")
    must_have_one_noun+=("Org.pro_rugby_team")
    must_have_one_noun+=("Org.pro_rugby_team")
    must_have_one_noun+=("Org.pro_rugby_team")
    must_have_one_noun+=("Org.pro_soccer_team")
    must_have_one_noun+=("Org.pro_soccer_team")
    must_have_one_noun+=("Org.pro_soccer_team")
    must_have_one_noun+=("Org.radio_station")
    must_have_one_noun+=("Org.radio_station")
    must_have_one_noun+=("Org.radio_station")
    must_have_one_noun+=("Org.religion")
    must_have_one_noun+=("Org.religion")
    must_have_one_noun+=("Org.religion")
    must_have_one_noun+=("Org.sports_league")
    must_have_one_noun+=("Org.sports_league")
    must_have_one_noun+=("Org.sports_league")
    must_have_one_noun+=("Org.standards")
    must_have_one_noun+=("Org.standards")
    must_have_one_noun+=("Org.standards")
    must_have_one_noun+=("Org.stock_exchange")
    must_have_one_noun+=("Org.stock_exchange")
    must_have_one_noun+=("Org.stock_exchange")
    must_have_one_noun+=("Org.stock_index")
    must_have_one_noun+=("Org.stock_index")
    must_have_one_noun+=("Org.stock_index")
    must_have_one_noun+=("Org.think_tank")
    must_have_one_noun+=("Org.think_tank")
    must_have_one_noun+=("Org.think_tank")
    must_have_one_noun+=("Org.trade_agreement")
    must_have_one_noun+=("Org.trade_agreement")
    must_have_one_noun+=("Org.trade_agreement")
    must_have_one_noun+=("Org.transit_authority")
    must_have_one_noun+=("Org.transit_authority")
    must_have_one_noun+=("Org.transit_authority")
    must_have_one_noun+=("Org.transit_system")
    must_have_one_noun+=("Org.transit_system")
    must_have_one_noun+=("Org.transit_system")
    must_have_one_noun+=("Org.treaty")
    must_have_one_noun+=("Org.treaty")
    must_have_one_noun+=("Org.treaty")
    must_have_one_noun+=("Person.academic")
    must_have_one_noun+=("Person.academic")
    must_have_one_noun+=("Person.academic")
    must_have_one_noun+=("Person.activist")
    must_have_one_noun+=("Person.activist")
    must_have_one_noun+=("Person.activist")
    must_have_one_noun+=("Person.actor")
    must_have_one_noun+=("Person.actor")
    must_have_one_noun+=("Person.actor")
    must_have_one_noun+=("Person.appearance")
    must_have_one_noun+=("Person.appearance")
    must_have_one_noun+=("Person.appearance")
    must_have_one_noun+=("Person.artist")
    must_have_one_noun+=("Person.artist")
    must_have_one_noun+=("Person.artist")
    must_have_one_noun+=("Person.astronaut")
    must_have_one_noun+=("Person.astronaut")
    must_have_one_noun+=("Person.astronaut")
    must_have_one_noun+=("Person.author")
    must_have_one_noun+=("Person.author")
    must_have_one_noun+=("Person.author")
    must_have_one_noun+=("Person.broadcaster")
    must_have_one_noun+=("Person.broadcaster")
    must_have_one_noun+=("Person.broadcaster")
    must_have_one_noun+=("Person.businessman")
    must_have_one_noun+=("Person.businessman")
    must_have_one_noun+=("Person.businessman")
    must_have_one_noun+=("Person.comedian")
    must_have_one_noun+=("Person.comedian")
    must_have_one_noun+=("Person.comedian")
    must_have_one_noun+=("Person.computer_scientist")
    must_have_one_noun+=("Person.computer_scientist")
    must_have_one_noun+=("Person.computer_scientist")
    must_have_one_noun+=("Person.criminal")
    must_have_one_noun+=("Person.criminal")
    must_have_one_noun+=("Person.criminal")
    must_have_one_noun+=("Person.director")
    must_have_one_noun+=("Person.director")
    must_have_one_noun+=("Person.director")
    must_have_one_noun+=("Person.economist")
    must_have_one_noun+=("Person.economist")
    must_have_one_noun+=("Person.economist")
    must_have_one_noun+=("Person.emotion")
    must_have_one_noun+=("Person.emotion")
    must_have_one_noun+=("Person.emotion")
    must_have_one_noun+=("Person.ethnicity")
    must_have_one_noun+=("Person.ethnicity")
    must_have_one_noun+=("Person.ethnicity")
    must_have_one_noun+=("Person.fictional_character")
    must_have_one_noun+=("Person.fictional_character")
    must_have_one_noun+=("Person.fictional_character")
    must_have_one_noun+=("Person.first_lady")
    must_have_one_noun+=("Person.first_lady")
    must_have_one_noun+=("Person.first_lady")
    must_have_one_noun+=("Person.first_nations")
    must_have_one_noun+=("Person.first_nations")
    must_have_one_noun+=("Person.first_nations")
    must_have_one_noun+=("Person.gender")
    must_have_one_noun+=("Person.gender")
    must_have_one_noun+=("Person.gender")
    must_have_one_noun+=("Person.government_employee")
    must_have_one_noun+=("Person.government_employee")
    must_have_one_noun+=("Person.government_employee")
    must_have_one_noun+=("Person.hacker")
    must_have_one_noun+=("Person.hacker")
    must_have_one_noun+=("Person.hacker")
    must_have_one_noun+=("Person.head_of_state_title")
    must_have_one_noun+=("Person.head_of_state_title")
    must_have_one_noun+=("Person.head_of_state_title")
    must_have_one_noun+=("Person.job_title")
    must_have_one_noun+=("Person.job_title")
    must_have_one_noun+=("Person.job_title")
    must_have_one_noun+=("Person.journalist")
    must_have_one_noun+=("Person.journalist")
    must_have_one_noun+=("Person.journalist")
    must_have_one_noun+=("Person.judge")
    must_have_one_noun+=("Person.judge")
    must_have_one_noun+=("Person.judge")
    must_have_one_noun+=("Person.language")
    must_have_one_noun+=("Person.language")
    must_have_one_noun+=("Person.language")
    must_have_one_noun+=("Person.law_enforcement")
    must_have_one_noun+=("Person.law_enforcement")
    must_have_one_noun+=("Person.law_enforcement")
    must_have_one_noun+=("Person.lawyer")
    must_have_one_noun+=("Person.lawyer")
    must_have_one_noun+=("Person.lawyer")
    must_have_one_noun+=("Person.military_personnel")
    must_have_one_noun+=("Person.military_personnel")
    must_have_one_noun+=("Person.military_personnel")
    must_have_one_noun+=("Person.military_rank")
    must_have_one_noun+=("Person.military_rank")
    must_have_one_noun+=("Person.military_rank")
    must_have_one_noun+=("Person.model")
    must_have_one_noun+=("Person.model")
    must_have_one_noun+=("Person.model")
    must_have_one_noun+=("Person.music_group")
    must_have_one_noun+=("Person.music_group")
    must_have_one_noun+=("Person.music_group")
    must_have_one_noun+=("Person.musician")
    must_have_one_noun+=("Person.musician")
    must_have_one_noun+=("Person.musician")
    must_have_one_noun+=("Person.nationality")
    must_have_one_noun+=("Person.nationality")
    must_have_one_noun+=("Person.nationality")
    must_have_one_noun+=("Person.philanthropist")
    must_have_one_noun+=("Person.philanthropist")
    must_have_one_noun+=("Person.philanthropist")
    must_have_one_noun+=("Person.philosopher")
    must_have_one_noun+=("Person.philosopher")
    must_have_one_noun+=("Person.philosopher")
    must_have_one_noun+=("Person.physician")
    must_have_one_noun+=("Person.physician")
    must_have_one_noun+=("Person.physician")
    must_have_one_noun+=("Person.playwright")
    must_have_one_noun+=("Person.playwright")
    must_have_one_noun+=("Person.playwright")
    must_have_one_noun+=("Person.poet")
    must_have_one_noun+=("Person.poet")
    must_have_one_noun+=("Person.poet")
    must_have_one_noun+=("Person.politician")
    must_have_one_noun+=("Person.politician")
    must_have_one_noun+=("Person.politician")
    must_have_one_noun+=("Person.pro_athlete")
    must_have_one_noun+=("Person.pro_athlete")
    must_have_one_noun+=("Person.pro_athlete")
    must_have_one_noun+=("Person.radio_host")
    must_have_one_noun+=("Person.radio_host")
    must_have_one_noun+=("Person.radio_host")
    must_have_one_noun+=("Person.relationship")
    must_have_one_noun+=("Person.relationship")
    must_have_one_noun+=("Person.relationship")
    must_have_one_noun+=("Person.religious_figure")
    must_have_one_noun+=("Person.religious_figure")
    must_have_one_noun+=("Person.religious_figure")
    must_have_one_noun+=("Person.religious_follower")
    must_have_one_noun+=("Person.religious_follower")
    must_have_one_noun+=("Person.religious_follower")
    must_have_one_noun+=("Person.religious_founder")
    must_have_one_noun+=("Person.religious_founder")
    must_have_one_noun+=("Person.religious_founder")
    must_have_one_noun+=("Person.royalty")
    must_have_one_noun+=("Person.royalty")
    must_have_one_noun+=("Person.royalty")
    must_have_one_noun+=("Person.scientist")
    must_have_one_noun+=("Person.scientist")
    must_have_one_noun+=("Person.scientist")
    must_have_one_noun+=("Person.software_engineer")
    must_have_one_noun+=("Person.software_engineer")
    must_have_one_noun+=("Person.software_engineer")
    must_have_one_noun+=("Person.sports_coach")
    must_have_one_noun+=("Person.sports_coach")
    must_have_one_noun+=("Person.sports_coach")
    must_have_one_noun+=("Person.sports_position")
    must_have_one_noun+=("Person.sports_position")
    must_have_one_noun+=("Person.sports_position")
    must_have_one_noun+=("Person.streamer")
    must_have_one_noun+=("Person.streamer")
    must_have_one_noun+=("Person.streamer")
    must_have_one_noun+=("Person.subculture")
    must_have_one_noun+=("Person.subculture")
    must_have_one_noun+=("Person.subculture")
    must_have_one_noun+=("Person.surgeon")
    must_have_one_noun+=("Person.surgeon")
    must_have_one_noun+=("Person.surgeon")
    must_have_one_noun+=("Person.terrorist")
    must_have_one_noun+=("Person.terrorist")
    must_have_one_noun+=("Person.terrorist")
    must_have_one_noun+=("Person.tv_presenter")
    must_have_one_noun+=("Person.tv_presenter")
    must_have_one_noun+=("Person.tv_presenter")
    must_have_one_noun+=("Person.us_president")
    must_have_one_noun+=("Person.us_president")
    must_have_one_noun+=("Person.us_president")
    must_have_one_noun+=("Person.whistleblower")
    must_have_one_noun+=("Person.whistleblower")
    must_have_one_noun+=("Person.whistleblower")
    must_have_one_noun+=("Person.world_leader")
    must_have_one_noun+=("Person.world_leader")
    must_have_one_noun+=("Person.world_leader")
    must_have_one_noun+=("Product.ETF")
    must_have_one_noun+=("Product.ETF")
    must_have_one_noun+=("Product.ETF")
    must_have_one_noun+=("Product.aircraft")
    must_have_one_noun+=("Product.aircraft")
    must_have_one_noun+=("Product.aircraft")
    must_have_one_noun+=("Product.album")
    must_have_one_noun+=("Product.album")
    must_have_one_noun+=("Product.album")
    must_have_one_noun+=("Product.automobile")
    must_have_one_noun+=("Product.automobile")
    must_have_one_noun+=("Product.automobile")
    must_have_one_noun+=("Product.beer")
    must_have_one_noun+=("Product.beer")
    must_have_one_noun+=("Product.beer")
    must_have_one_noun+=("Product.book")
    must_have_one_noun+=("Product.book")
    must_have_one_noun+=("Product.book")
    must_have_one_noun+=("Product.cargo_ship")
    must_have_one_noun+=("Product.cargo_ship")
    must_have_one_noun+=("Product.cargo_ship")
    must_have_one_noun+=("Product.cleaning")
    must_have_one_noun+=("Product.cleaning")
    must_have_one_noun+=("Product.cleaning")
    must_have_one_noun+=("Product.clothing")
    must_have_one_noun+=("Product.clothing")
    must_have_one_noun+=("Product.clothing")
    must_have_one_noun+=("Product.cocktail")
    must_have_one_noun+=("Product.cocktail")
    must_have_one_noun+=("Product.cocktail")
    must_have_one_noun+=("Product.coffee")
    must_have_one_noun+=("Product.coffee")
    must_have_one_noun+=("Product.coffee")
    must_have_one_noun+=("Product.commodity")
    must_have_one_noun+=("Product.commodity")
    must_have_one_noun+=("Product.commodity")
    must_have_one_noun+=("Product.cpu")
    must_have_one_noun+=("Product.cpu")
    must_have_one_noun+=("Product.cpu")
    must_have_one_noun+=("Product.cryptocurrency")
    must_have_one_noun+=("Product.cryptocurrency")
    must_have_one_noun+=("Product.cryptocurrency")
    must_have_one_noun+=("Product.currency")
    must_have_one_noun+=("Product.currency")
    must_have_one_noun+=("Product.currency")
    must_have_one_noun+=("Product.digital_media_player")
    must_have_one_noun+=("Product.digital_media_player")
    must_have_one_noun+=("Product.digital_media_player")
    must_have_one_noun+=("Product.fashion_accessory")
    must_have_one_noun+=("Product.fashion_accessory")
    must_have_one_noun+=("Product.fashion_accessory")
    must_have_one_noun+=("Product.financial")
    must_have_one_noun+=("Product.financial")
    must_have_one_noun+=("Product.financial")
    must_have_one_noun+=("Product.food")
    must_have_one_noun+=("Product.food")
    must_have_one_noun+=("Product.food")
    must_have_one_noun+=("Product.headphones")
    must_have_one_noun+=("Product.headphones")
    must_have_one_noun+=("Product.headphones")
    must_have_one_noun+=("Product.jewellery")
    must_have_one_noun+=("Product.jewellery")
    must_have_one_noun+=("Product.jewellery")
    must_have_one_noun+=("Product.laptop")
    must_have_one_noun+=("Product.laptop")
    must_have_one_noun+=("Product.laptop")
    must_have_one_noun+=("Product.laundry_detergent")
    must_have_one_noun+=("Product.laundry_detergent")
    must_have_one_noun+=("Product.laundry_detergent")
    must_have_one_noun+=("Product.magazine")
    must_have_one_noun+=("Product.magazine")
    must_have_one_noun+=("Product.magazine")
    must_have_one_noun+=("Product.manufacturing")
    must_have_one_noun+=("Product.manufacturing")
    must_have_one_noun+=("Product.manufacturing")
    must_have_one_noun+=("Product.military_ship")
    must_have_one_noun+=("Product.military_ship")
    must_have_one_noun+=("Product.military_ship")
    must_have_one_noun+=("Product.movie")
    must_have_one_noun+=("Product.movie")
    must_have_one_noun+=("Product.movie")
    must_have_one_noun+=("Product.music_genre")
    must_have_one_noun+=("Product.music_genre")
    must_have_one_noun+=("Product.music_genre")
    must_have_one_noun+=("Product.musical_instrument")
    must_have_one_noun+=("Product.musical_instrument")
    must_have_one_noun+=("Product.musical_instrument")
    must_have_one_noun+=("Product.personal_hygiene")
    must_have_one_noun+=("Product.personal_hygiene")
    must_have_one_noun+=("Product.personal_hygiene")
    must_have_one_noun+=("Product.pipeline_system")
    must_have_one_noun+=("Product.pipeline_system")
    must_have_one_noun+=("Product.pipeline_system")
    must_have_one_noun+=("Product.podcast")
    must_have_one_noun+=("Product.podcast")
    must_have_one_noun+=("Product.podcast")
    must_have_one_noun+=("Product.pornography")
    must_have_one_noun+=("Product.pornography")
    must_have_one_noun+=("Product.pornography")
    must_have_one_noun+=("Product.registered_investment")
    must_have_one_noun+=("Product.registered_investment")
    must_have_one_noun+=("Product.registered_investment")
    must_have_one_noun+=("Product.sex_toy")
    must_have_one_noun+=("Product.sex_toy")
    must_have_one_noun+=("Product.sex_toy")
    must_have_one_noun+=("Product.smartphone")
    must_have_one_noun+=("Product.smartphone")
    must_have_one_noun+=("Product.smartphone")
    must_have_one_noun+=("Product.smartwatch")
    must_have_one_noun+=("Product.smartwatch")
    must_have_one_noun+=("Product.smartwatch")
    must_have_one_noun+=("Product.soft_drink")
    must_have_one_noun+=("Product.soft_drink")
    must_have_one_noun+=("Product.soft_drink")
    must_have_one_noun+=("Product.space_shuttle")
    must_have_one_noun+=("Product.space_shuttle")
    must_have_one_noun+=("Product.space_shuttle")
    must_have_one_noun+=("Product.sports_equipment")
    must_have_one_noun+=("Product.sports_equipment")
    must_have_one_noun+=("Product.sports_equipment")
    must_have_one_noun+=("Product.tablet")
    must_have_one_noun+=("Product.tablet")
    must_have_one_noun+=("Product.tablet")
    must_have_one_noun+=("Product.tea")
    must_have_one_noun+=("Product.tea")
    must_have_one_noun+=("Product.tea")
    must_have_one_noun+=("Product.tv_episode")
    must_have_one_noun+=("Product.tv_episode")
    must_have_one_noun+=("Product.tv_episode")
    must_have_one_noun+=("Product.tv_show")
    must_have_one_noun+=("Product.tv_show")
    must_have_one_noun+=("Product.tv_show")
    must_have_one_noun+=("Product.vehicle")
    must_have_one_noun+=("Product.vehicle")
    must_have_one_noun+=("Product.vehicle")
    must_have_one_noun+=("Product.video_game")
    must_have_one_noun+=("Product.video_game")
    must_have_one_noun+=("Product.video_game")
    must_have_one_noun+=("Product.video_game_console")
    must_have_one_noun+=("Product.video_game_console")
    must_have_one_noun+=("Product.video_game_console")
    must_have_one_noun+=("Product.watch")
    must_have_one_noun+=("Product.watch")
    must_have_one_noun+=("Product.watch")
    must_have_one_noun+=("Product.weapon")
    must_have_one_noun+=("Product.weapon")
    must_have_one_noun+=("Product.weapon")
    must_have_one_noun+=("Product.wine")
    must_have_one_noun+=("Product.wine")
    must_have_one_noun+=("Product.wine")
    must_have_one_noun+=("Science.bacteria")
    must_have_one_noun+=("Science.bacteria")
    must_have_one_noun+=("Science.bacteria")
    must_have_one_noun+=("Science.chemical_compound")
    must_have_one_noun+=("Science.chemical_compound")
    must_have_one_noun+=("Science.chemical_compound")
    must_have_one_noun+=("Science.chemical_element")
    must_have_one_noun+=("Science.chemical_element")
    must_have_one_noun+=("Science.chemical_element")
    must_have_one_noun+=("Science.fatty_acids")
    must_have_one_noun+=("Science.fatty_acids")
    must_have_one_noun+=("Science.fatty_acids")
    must_have_one_noun+=("Science.galaxy")
    must_have_one_noun+=("Science.galaxy")
    must_have_one_noun+=("Science.galaxy")
    must_have_one_noun+=("Science.isotope")
    must_have_one_noun+=("Science.isotope")
    must_have_one_noun+=("Science.isotope")
    must_have_one_noun+=("Science.mineral")
    must_have_one_noun+=("Science.mineral")
    must_have_one_noun+=("Science.mineral")
    must_have_one_noun+=("Science.molecule")
    must_have_one_noun+=("Science.molecule")
    must_have_one_noun+=("Science.molecule")
    must_have_one_noun+=("Science.particle")
    must_have_one_noun+=("Science.particle")
    must_have_one_noun+=("Science.particle")
    must_have_one_noun+=("Science.planet")
    must_have_one_noun+=("Science.planet")
    must_have_one_noun+=("Science.planet")
    must_have_one_noun+=("Science.plant")
    must_have_one_noun+=("Science.plant")
    must_have_one_noun+=("Science.plant")
    must_have_one_noun+=("Science.protein")
    must_have_one_noun+=("Science.protein")
    must_have_one_noun+=("Science.protein")
    must_have_one_noun+=("Science.star")
    must_have_one_noun+=("Science.star")
    must_have_one_noun+=("Science.star")
    must_have_one_noun+=("Science.theory")
    must_have_one_noun+=("Science.theory")
    must_have_one_noun+=("Science.theory")
    must_have_one_noun+=("Technology.algorithm")
    must_have_one_noun+=("Technology.algorithm")
    must_have_one_noun+=("Technology.algorithm")
    must_have_one_noun+=("Technology.component")
    must_have_one_noun+=("Technology.component")
    must_have_one_noun+=("Technology.component")
    must_have_one_noun+=("Technology.cpu_architecture")
    must_have_one_noun+=("Technology.cpu_architecture")
    must_have_one_noun+=("Technology.cpu_architecture")
    must_have_one_noun+=("Technology.cpu_extensions")
    must_have_one_noun+=("Technology.cpu_extensions")
    must_have_one_noun+=("Technology.cpu_extensions")
    must_have_one_noun+=("Technology.datastructure")
    must_have_one_noun+=("Technology.datastructure")
    must_have_one_noun+=("Technology.datastructure")
    must_have_one_noun+=("Technology.encryption")
    must_have_one_noun+=("Technology.encryption")
    must_have_one_noun+=("Technology.encryption")
    must_have_one_noun+=("Technology.file_format")
    must_have_one_noun+=("Technology.file_format")
    must_have_one_noun+=("Technology.file_format")
    must_have_one_noun+=("Technology.imaging")
    must_have_one_noun+=("Technology.imaging")
    must_have_one_noun+=("Technology.imaging")
    must_have_one_noun+=("Technology.infotainment")
    must_have_one_noun+=("Technology.infotainment")
    must_have_one_noun+=("Technology.infotainment")
    must_have_one_noun+=("Technology.input_device")
    must_have_one_noun+=("Technology.input_device")
    must_have_one_noun+=("Technology.input_device")
    must_have_one_noun+=("Technology.markup")
    must_have_one_noun+=("Technology.markup")
    must_have_one_noun+=("Technology.markup")
    must_have_one_noun+=("Technology.mobile_interface")
    must_have_one_noun+=("Technology.mobile_interface")
    must_have_one_noun+=("Technology.mobile_interface")
    must_have_one_noun+=("Technology.network")
    must_have_one_noun+=("Technology.network")
    must_have_one_noun+=("Technology.network")
    must_have_one_noun+=("Technology.operating_system")
    must_have_one_noun+=("Technology.operating_system")
    must_have_one_noun+=("Technology.operating_system")
    must_have_one_noun+=("Technology.programming_language")
    must_have_one_noun+=("Technology.programming_language")
    must_have_one_noun+=("Technology.programming_language")
    must_have_one_noun+=("Technology.protocol")
    must_have_one_noun+=("Technology.protocol")
    must_have_one_noun+=("Technology.protocol")
    must_have_one_noun+=("Technology.security_exploit")
    must_have_one_noun+=("Technology.security_exploit")
    must_have_one_noun+=("Technology.security_exploit")
    must_have_one_noun+=("Technology.social_network")
    must_have_one_noun+=("Technology.social_network")
    must_have_one_noun+=("Technology.social_network")
    must_have_one_noun+=("Technology.software")
    must_have_one_noun+=("Technology.software")
    must_have_one_noun+=("Technology.software")
    must_have_one_noun+=("Technology.software_development_process")
    must_have_one_noun+=("Technology.software_development_process")
    must_have_one_noun+=("Technology.software_development_process")
    must_have_one_noun+=("Technology.software_license")
    must_have_one_noun+=("Technology.software_license")
    must_have_one_noun+=("Technology.software_license")
    must_have_one_noun+=("Technology.streaming_service")
    must_have_one_noun+=("Technology.streaming_service")
    must_have_one_noun+=("Technology.streaming_service")
    must_have_one_noun+=("Technology.typeface")
    must_have_one_noun+=("Technology.typeface")
    must_have_one_noun+=("Technology.typeface")
    must_have_one_noun+=("Technology.virtual_reality")
    must_have_one_noun+=("Technology.virtual_reality")
    must_have_one_noun+=("Technology.virtual_reality")
    must_have_one_noun+=("Time.day")
    must_have_one_noun+=("Time.day")
    must_have_one_noun+=("Time.day")
    must_have_one_noun+=("Time.holiday")
    must_have_one_noun+=("Time.holiday")
    must_have_one_noun+=("Time.holiday")
    must_have_one_noun+=("Time.month")
    must_have_one_noun+=("Time.month")
    must_have_one_noun+=("Time.month")
    must_have_one_noun+=("Time.period")
    must_have_one_noun+=("Time.period")
    must_have_one_noun+=("Time.period")
    must_have_one_noun+=("Time.season")
    must_have_one_noun+=("Time.season")
    must_have_one_noun+=("Time.season")
    must_have_one_noun+=("Time.time_of_day")
    must_have_one_noun+=("Time.time_of_day")
    must_have_one_noun+=("Time.time_of_day")
    must_have_one_noun+=("Time.year")
    must_have_one_noun+=("Time.year")
    must_have_one_noun+=("Time.year")
    noun_aliases=()
}

_cli_root_command()
{
    last_command="cli"

    command_aliases=()

    commands=()
    commands+=("index")
    commands+=("search")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_cli()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __cli_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("cli")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function
    local last_command
    local nouns=()

    __cli_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_cli cli
else
    complete -o default -o nospace -F __start_cli cli
fi

# ex: ts=4 sw=4 et filetype=sh
