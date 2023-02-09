#!/bin/bash

echo_args() {
    echo "${@}"
}

# See https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
# for explanation of flags.
set -ue

# Define text formatting commands.
# - textbf: Use bold-face.
# - textnm: Reset to normal.
# - startul: Start underlined text.
# - endul: End underlined text.
textbf=$(tput bold)
textnm=$(tput sgr0)
startul=$(tput smul)
endul=$(tput rmul)

# This is the CLI's main help text.
show_help()
{
    cli_name=${0##*/}
    echo "
${textbf}NAME${textnm}
        $cli_name - Test the EPREM command-line runtime interface.

${textbf}SYNOPSIS${textnm}
        ${textbf}$cli_name${textnm} [${startul}OPTION${endul}]

${textbf}DESCRIPTION${textnm}
        This script will test all subcommands of the EPREM runtime 
        command-line utility.

        ${textbf}-h${textnm}, ${textbf}--help${textnm}
                Display help and exit.
        ${textbf}-d=DIR${textnm}, ${textbf}--directory=DIR${textnm}
                The directory in which to create the test project
                (default: current directory).
        ${textbf}-k${textnm}, ${textbf}--keep${textnm}
                Do not automatically remove the project.
        ${textbf}-v${textnm}, ${textbf}--verbose${textnm}
                Print runtime messages; repeat to increase verbosity.
        ${textbf}--dry-run${textnm}
                Print the sequence of commands but do not execute them.
"
}

report_bad_args() {
    show_help
    for arg in $@; do
        echo "Unrecognized argument: ${arg}"
    done
    exit 1
}

# Parse command-line options. See
# `/usr/share/doc/util-linux/examples/getopt-example.bash` and the `getopt`
# manual page for more information.
TEMP=$(getopt \
    -n 'test.sh' \
    -o 'hd:kv' \
    -l 'help,directory:,keep,verbose' \
    -l 'dry-run' \
    -- "$@")

if [ $? -ne 0 ]; then
    echo "Failed to parse command-line arguments. Terminating."
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

# Set option defaults.
directory=$(pwd)
keep=0
verbose=0
verbosity=0
dry_run=0

# Parse optional command-line arguments.
while [ $# -gt 0 ]; do
    case "$1" in
        '-h'|'--help')
            show_help
            exit
        ;;
        '-d'|'--directory')
            directory="${2}"
            shift 2
            continue
        ;;
        '-i'|'--interactive')
            show_help
            echo "This script does not support the -i/--interactive option."
            echo "Please use ${textbf}test.py${textnm} for interactive testing."
            exit 1
        ;;
        '-k'|'--keep')
            keep=1
            shift
            continue
        ;;
        '-v'|'--verbosity')
            verbosity=$((verbosity+1))
            shift
            continue
        ;;
        '--dry-run')
            dry_run=1
            shift
            continue
        ;;
        '--')
            shift
            break
        ;;
    esac
done

# Set `verbose` boolean from `verbosity` integer.
if [ ${verbosity} -gt 0 ]; then
    verbose=1
fi

# Check for invalid arguments.
if [ $# -gt 0 ]; then
    report_bad_args $@
fi

# Store name of code directory.
here=$(dirname ${0})

# Declare path to Python interface.
prog=${here}

# Store interface command for convenience.
runprog="python ${prog}"

# Declare path to config file.
config=${here}/test.cfg

call_interface() {
    local subcmnd="${1}"
    shift
    args="${@} "
    if [ "${subcmnd}" != "show" -a ${verbose} -gt 0 ]; then
        args+="-v "
    fi
    cmnd=(${runprog} $subcmnd $args)
    if [ ${dry_run} == 1 ]; then
        echo_args "[DRY RUN]" ${cmnd[@]}
    else
        ${cmnd[@]}
    fi
    echo 
}

test_run() {

    # Assume that the arguments, if any, are requested branches.
    branches="${@}"

    # Set up the project path.
    now="$(date +%Y-%m-%d)T$(date +%H-%M-%S)"
    path="${directory}"/testprj_${now}

    # Define a function to execute the current project.
    call_project() {
        local project="${1}"
        shift
        args="${@} "
        if [ ${verbose} -gt 0 ]; then
            args+="-v "
        fi
        cmnd=(python $project $args)
        if [ ${dry_run} == 1 ]; then
            echo_args "[DRY RUN]" ${cmnd[@]}
        else
            ${cmnd[@]}
        fi
        echo 
    }

    # Define a function to remove the current project.
    remove_project() {
        if [ ${keep} == 0 ]; then
            call_interface remove "${1}"
        fi
    }

    # Define the clean-up action based on the current project.
    on_error() {
        echo "Caught error signal."
        remove_project "${path}"
        exit 255
    }
    trap on_error ERR

    # Create the test project.
    if [ -n "${branches}" ]; then
        call_interface create ${path} -b ${branches}
    else
        call_interface create ${path}
    fi

    # Create two test runs (in each branch, if applicable).
    for target in run00 run01; do
        call_project ${path} run -n 2 -t ${target} ${config}
    done

    # Display a project-wide summary.
    call_interface show ${path}

    # Rename runs.
    if [ -n "${branches}" ]; then
        call_project ${path} mv run00 run0
        call_project ${path} mv run01 run1A -b A
        call_project ${path} mv run01 run1B -b B
    else
        call_project ${path} mv run00 run0
        call_project ${path} mv run01 run1
    fi

    # Display a run-specific summary.
    call_interface show ${path} -a

    # Remove runs.
    if [ -n "${branches}" ]; then
        call_project ${path} rm run1A
        call_project ${path} rm run1B
        call_project ${path} rm run0 -b A
    else
        call_project ${path} rm run1
    fi

    # Rename the project.
    newname="renamed_${now}"
    call_interface rename ${path} ${newname}
    path="${directory}"/${newname}

    # Reset the project.
    call_interface reset ${path}

    # Remove the test project, if necessary.
    remove_project ${path}
    echo "Tests finished normally"
    echo 
}

# Test without branches.
test_run

# Sleep for 1 second to ensure distinct project names.
sleep 1

# Test with branches.
test_run A B

