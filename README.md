# EPREM Runtime Interface
Interactively manage collections of EPREM simulation runs.

This repository houses a multi-facted interface that allows EPREM users to intuitively and interactively manage distinct collections of simulation runs. Each collection is referred to as a *project*. A project stores individual simulation runs in a known subdirectory, which allows it to keep track of metadata such as the time of executation and the full executing command. The interface allows users to rename or remove individual runs within a given project via familiar syntax while consistently updating the associated metadata. A project may also have multiple branches, thereby allowing multiple variants that logically belong together (e.g., testing multiple versions of the code).

The core functionality is written in Python and includes two interface varieties: a command-line utility and an interative Python library.
