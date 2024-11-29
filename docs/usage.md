# pvacseq: Usage

## Introduction

This pipeline is built using the **nf-core** template, providing a standardized structure. However, the pipeline is not yet published in the nf-core repository.

The pipeline is designed to run the **pVACseq** tool on multiple tumor samples in different environments.

## Input Directory with VCF/MAF Files

The pVACseq pipeline requires a directory with VCF or MAF files for each sample. Both file types are supported, and MAF files will automatically be converted to VCF format during processing. Use this parameter to specify its location. 
```
--input '[path to directory]'
```

### Directory Structure

- The input directory can contain both VCF and MAF files.
- **VCF Files**: Must include sample genotype information (`GT` field) as described in the [pVACtools documentation](https://pvactools.readthedocs.io/en/latest/pvacseq/input_file_prep/gt.html).
- **MAF Files**: Will be transformed to VCF format before processing.

### Example Directory Structure

```plaintext
input_vcf_maf/
├── sample1.vcf
├── sample2.maf
├── sample3.vcf
```

## HLA Input

The pVACseq pipeline requires an input file specifying HLA alleles for each sample. This is essential for neoantigen prediction. Use this parameter to specify its location. 
```
--hla_csv '[path to file with hla information]'
```

### CSV Structure

The HLA input file must be a comma-separated file (CSV) with the following columns:

| Column      | Description                                                                                                            |
|-------------|------------------------------------------------------------------------------------------------------------------------|
| `Sample_ID` | Unique sample identifier. This must match the sample name inside the input VCF or MAF file, **not** the file name.     |
| `HLA_Types` | Semicolon-separated list of HLA alleles in the format `HLA-[Gene][Allele group]:[Protein]`.                            |

- **Header Row**: The first row must contain column names (`Sample_ID`, `HLA_Types`).
- **Unique Samples**: Each row corresponds to one unique sample.

### HLA Format

HLA alleles must use the `HLA-[Gene][Allele group]:[Protein]` format. Examples:
- `HLA-A02:01`
- `HLA-B15:01`
- `HLA-C07:02`

Alleles in the `HLA_Types` column must be separated by semicolons `;`.

### Example HLA Input File

```csv title="hla_input.csv"
Sample_ID,HLA_Types
SAMPLE_1,HLA-C06:02;HLA-B45:01
SAMPLE_2,HLA-A29:02;HLA-B44:02;HLA-A02:01
SAMPLE_3,HLA-A11:01;HLA-B35:01;HLA-C04:01
```

## Reference FASTA File Input

The pVACseq pipeline requires a reference genome in FASTA format to match the input VCF or MAF files. Use this parameter to specify its location. 
```
--fasta '[path to reference file]'
```

### Requirements

- The FASTA file must be **unzipped**. Compressed versions (e.g., `.fa.gz`) are not currently supported.
- Ensure the FASTA file corresponds to the correct reference genome version used for the input VCF/MAF files.

## VEP Parameters

The pVACseq pipeline uses VEP (Variant Effect Predictor) for annotating input variants. Below are the parameters required for the tool and their behavior in the pipeline:

### Parameters

1. **`vep_cache`**: Directory containing the VEP cache files.
2. **`vep_cache_version`**: Version of the VEP cache to use. If not specified, the default version is `102`.
3. **`vep_plugins`**: Directory containing VEP plugins.

### Automatic download

#### **`vep_plugins`**
- If `vep_plugins` is not provided, the pipeline will download the required plugins automatically.
- If you rerun the pipeline without specifying `vep_plugins`, it will detect the already downloaded plugins and fail due to conflicting directory states.
- To avoid this issue, specify the downloaded plugin directory in subsequent runs using the `vep_plugins` parameter.

#### **`vep_cache` and `vep_cache_version`**
- **When `vep_cache_version` is provided but `vep_cache` is not**:
  - The pipeline will attempt to download the specified cache version.
  - The same logic as `vep_plugins` applies: specify the cache directory (`vep_cache`) on reruns to avoid download conflicts.
- **When `vep_cache_version` is not provided but `vep_cache` is specified**:
  - The pipeline will fail because it cannot infer the cache version from the directory.
- **When neither `vep_cache_version` nor `vep_cache` is provided**:
  - The pipeline will use the default cache version (`102`) and download it automatically.

### Best Practices

- Always specify the `vep_cache` and `vep_plugins` directories after the first run to avoid conflicts and unnecessary downloads.
- Ensure the `vep_cache_version` matches the version of the `vep_cache` directory provided.


## pVACseq Parameters

The pVACseq pipeline provides a range of configurable options for neoantigen prediction. Below are the key parameters and their behavior:

### Required Parameters

1. **`pvacseq_algorithm`**: Specifies the algorithms to use for pVACseq predictions. This is required.
2. **`pvacseq_peptide_length_i`**: List of peptide lengths for MHC class I predictions. Required if MHC class I algorithms are selected.
3. **`pvacseq_peptide_length_ii`**: List of peptide lengths for MHC class II predictions. Required if MHC class II algorithms are selected.
#### **`pvacseq_iedb`**
- Path to the IEDB directory.
- If not provided:
  - The pipeline will automatically download the required IEDB tools for MHC class I and/or MHC class II based on the specified algorithms.
  - Only the required components (`mhc_i`, `mhc_ii`, or both) will be downloaded.
- **Rerun Behavior**:
  - If IEDB is downloaded automatically, specify the downloaded path in the `pvacseq_iedb` parameter on reruns to avoid conflicts.

### Optional Parameters
#### **`pvacseq_advanced_options`**
- Dictionary of advanced pVACseq options.
- Example:
  ```groovy
  pvacseq_advanced_options = [
      "binding-threshold": 500,
      "minimum-fold-change": 1.0
  ]
  ```
- Allows customization of parameters like `binding-threshold` and other algorithm-specific options.

## Running the Pipeline

To run the pVACseq pipeline, provide all required parameters in a configuration file and execute the pipeline using the following command:

```bash
nextflow run main.nf -profile <conda/docker>
```

### Test Profile

A `test` profile is available for running the pipeline with test data. The test dataset includes a MAF file derived from the TCGA dataset of a human tumor. Since pVACseq supports only human data, running the test profile requires large files such as the reference genome and associated databases.

### Resources Required for Testing

- **Time**: The test run will take approximately **1 hour** to complete.
- **Disk Space**: At least **50GB** of storage is needed to download and prepare all necessary databases and tools.

