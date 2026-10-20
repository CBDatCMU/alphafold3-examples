--
-- AlphaFold 3 modulefile
--
-- "URL: https://www.psc.edu/resources/software"
-- "Category: Biological Sciences"
-- "Description: AlphaFold 3 biomolecular structure prediction (Singularity container)."
-- "Keywords: protein structure, structure prediction, deep learning"

-- Install as /shared/containers/modulefiles/alphafold3/<version>.lua, one copy per
-- container in $AF3_IMAGES (3.0.0 to 3.0.4). The version is taken from the
-- module file name, so the same file works for every version.
local version = myModuleVersion()
if version == nil or not version:match("^%d+%.%d+%.%d+$") then
  version = "3.0.4"
end

whatis("Name: AlphaFold 3")
whatis("Version: " .. version)
whatis("Category: Biological Sciences")
whatis("URL: https://www.psc.edu/resources/software")
whatis("Description: AlphaFold 3 biomolecular structure prediction (Singularity container).")

help([[
AlphaFold 3 ]] .. version .. [[

----------------

Description
-----------
AlphaFold 3 predicts the structure of proteins, DNA, RNA, ligands, ions and
their complexes. It runs from a Singularity container, with the genetic
databases and model weights kept in /shared/containers/images/alphafold3.

Containers are available for versions 3.0.0, 3.0.1, 3.0.2, 3.0.3 and 3.0.4.

Use the weights only under the terms in $AF3_WEIGHTS/WEIGHTS_TERMS_OF_USE.md.

To load the module type

> module load alphafold3/]] .. version .. [[


Environment variables
---------------------
AF3_VERSION    AlphaFold 3 version of this module
AF3_ROOT       Top of the AlphaFold 3 dataset
AF3_IMAGES     Directory holding the AlphaFold 3 containers, one per version
AF3_IMAGE      Container for this version
AF3_DATABASES  Genetic databases and mmCIF files, for --db_dir (data pipeline)
AF3_WEIGHTS    Model weights (af3.bin.zst), for --model_dir (inference)
AF3_CODE       AlphaFold 3 source code, for reference

AF3_DB_DIR and AF3_MODEL_DIR are also set, to the same values as
AF3_DATABASES and AF3_WEIGHTS, because the stage1.sh and stage2.sh example
scripts read those names.

Databases
---------
bfd-first_non_consensus_sequences.fasta
mgy_clusters_2022_05.fa
nt_rna_2023_02_23_clust_seq_id_90_cov_80_rep_seq.fasta
pdb_seqres_2022_09_28.fasta
rfam_14_9_clust_seq_id_90_cov_80_rep_seq.fasta
rnacentral_active_seq_id_90_cov_80_linclust.fasta
uniprot_all_2021_04.fa
uniref90_2022_05.fa
mmcif_files/

Running
-------
run_alphafold runs run_alphafold.py inside the container, with /shared (and
/scratch, where present) bound and GPU support turned on when a GPU is
present. For example, the data pipeline alone on a CPU node:

> run_alphafold --json_path=fold_input.json --db_dir=$AF3_DATABASES \
    --output_dir=output --norun_inference

and inference alone on a GPU node:

> run_alphafold --json_path=output/<name>/<name>_data.json \
    --model_dir=$AF3_WEIGHTS --output_dir=output --norun_data_pipeline

Documentation
-------------
https://github.com/google-deepmind/alphafold3
]])

local root   = "/shared/containers/images/alphafold3"
local images = pathJoin(root, "images")
local image  = pathJoin(images, "singularity-alphafold3-v" .. version .. ".sif")

if mode() == "load" and not isFile(image) then
  LmodError("AlphaFold 3 container not found: " .. image)
end

setenv("AF3_VERSION",   version)
setenv("AF3_ROOT",      root)
setenv("AF3_IMAGES",    images)
setenv("AF3_IMAGE",     image)
setenv("AF3_DATABASES", pathJoin(root, "databases"))
setenv("AF3_WEIGHTS",   pathJoin(root, "weights"))
setenv("AF3_CODE",      pathJoin(root, "code", "alphafold3"))

-- Names read by the example stage1.sh and stage2.sh scripts.
setenv("AF3_DB_DIR",    pathJoin(root, "databases"))
setenv("AF3_MODEL_DIR", pathJoin(root, "weights"))

-- Run run_alphafold.py in the container. --nv is added only when nvidia-smi
-- finds a GPU, so the same command works on CPU and GPU nodes. $PROJECT is
-- bound only when it is set, and /scratch only when the node has it. Lmod
-- joins the body onto one line, so each command must end with a semicolon.
local bash_func = table.concat({
  'local nv="" binds="/shared${PROJECT:+,$PROJECT}";',
  '[ -d /scratch ] && binds="$binds,/scratch";',
  'nvidia-smi -L >/dev/null 2>&1 && nv="--nv";',
  'singularity exec $nv --bind "$binds"',
  '"$AF3_IMAGE" python /app/alphafold/run_alphafold.py "$@";',
}, " ")
local csh_func = 'singularity exec --bind /shared "$AF3_IMAGE" python /app/alphafold/run_alphafold.py $*'
set_shell_function("run_alphafold", bash_func, csh_func)
