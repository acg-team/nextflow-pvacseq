## Introduction

**nf-core/pvacseq** is a bioinformatics pipeline that transforms MAF files to VCF, annotates them with VEP, and analyzes them with pVACseq to facilitate the investigation of neoantigens.

## Introduction

The `nf-core/pvacseq` pipeline is designed for the prediction of neoantigens from genomic data using [pVACseq](https://pvactools.readthedocs.io/en/latest/tools/pvacseq.html). It supports inputs in both MAF and VCF formats.

## Pipeline Summary

The pipeline performs the following steps:

1. **Input Preprocessing**:
   - Accepts MAF or VCF files as input.
   - Converts MAF to VCF (if required) using [maf2vcf](https://github.com/mskcc/vcf2maf/tree/main).

2. **Variant Annotation**:
   - Annotates variants using [VEP](https://www.ensembl.org/info/docs/tools/vep/index.html), configured to meet the requirements of pVACseq.

3. **Loading HLA**:
   - Reads and processes HLA typing information from a user-provided CSV file.

4. **pVACseq Setup**:
   - Configures and downloads MHC class I and II files required for pVACseq if not provided and configure pvacseq environment.

5. **pVACseq Execution**:
   - Predicts neoantigens using [pVACseq](https://pvactools.readthedocs.io/en/latest/tools/pvacseq.html).

6. **MultiQC**:
   - Aggregates pipeline results with [MultiQC](http://multiqc.info/).

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow.

### Required Inputs

To run the pipeline, you need the following inputs:

1. **Input Files**:
   - A directory containing `*.maf` or `*.vcf` files.
2. **HLA Typing Information**:
   - A CSV file (`--hla_csv`) with the following structure:
     ```
     Sample_ID,HLA_Types
     TCGA-G4-6310-01A-11D-1719-10,HLA-C05:01;HLA-C06:02;HLA-B45:01;HLA-A29:02;HLA-B44:02;HLA-A02:01
     ```
3. **Reference Genome**:
   - A FASTA file (`--fasta`).

4. **VEP Requirements** (Optional):
   - The pipeline uses VEP for variant annotation. You can provide the following files if available:
     - **VEP Cache** (`--vep_cache`): Directory containing pre-downloaded VEP cache files.
     - **VEP Plugins** (`--vep_plugins`): Directory containing [required VEP plugins](https://pvactools.readthedocs.io/en/latest/pvacseq/input_file_prep/vep.html).
   - If these files are not provided, the pipeline will download the required VEP cache and plugins automatically.

5. **pVACseq Requirements** (Optional):
   - The pipeline uses IEDB for neoantigen prediction. You can provide the following directory if available:
     - **IEDB Installation Directory** (`--pvacseq_iedb`): Directory containing MHC class I and/or II files for IEDB.
   - If this directory is not provided, the pipeline will download and configure IEDB automatically.

### Running the Pipeline

You can run the pipeline using the following command:

```bash
nextflow run main.nf \
   -profile <docker/conda> \
   --input <INPUT DIRECTORY> \
   --hla_csv <HLA CSV FILE> \
   --fasta <REFERENCE FASTA> \
   --outdir <OUTPUT DIRECTORY>
```
### Testing the Pipeline
If you want to test the pipeline, you need to download the reference genome from [GDC Reference Files](https://gdc.cancer.gov/about-data/gdc-data-processing/gdc-reference-files). Once downloaded, you can run the test profile as follows:

```bash
nextflow run main.nf \
   -profile test,<docker/conda> \
   --outdir <OUTPUT DIRECTORY> \
   --fasta <PATH TO FASTA>
```

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use nf-core/pvacseq for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).

- [pVACseq](https://pvactools.readthedocs.io/en/latest/index.html)

  > Jasreet Hundal+, Susanna Kiwala+, Joshua McMichael, Christopher A Miller, Alexander T Wollam, Huiming Xia, Connor J Liu, Sidi Zhao, Yang-Yang Feng, Aaron P Graubert, Amber Z Wollam, Jonas Neichin, Megan Neveau, Jason Walker, William E Gillanders, Elaine R Mardis, Obi L Griffith, Malachi Griffith. pVACtools: a computational toolkit to select and visualize cancer neoantigens. Cancer Immunology Research. 2020 Mar;8(3):409-420. DOI: 10.1158/2326-6066.CIR-19-0401. PMID: 31907209. (+) equal contribution.

  > Jasreet Hundal, Susanna Kiwala, Yang-Yang Feng, Connor J. Liu, Ramaswamy Govindan, William C. Chapman, Ravindra Uppaluri, S. Joshua Swamidass, Obi L. Griffith, Elaine R. Mardis, and Malachi Griffith. Accounting for proximal variants improves neoantigen prediction. Nature Genetics. 2018, DOI: 10.1038/s41588-018-0283-9. PMID: 30510237.

  > Jasreet Hundal, Beatriz M. Carreno, Allegra A. Petti, Gerald P. Linette, Obi L. Griffith, Elaine R. Mardis, and Malachi Griffith. pVACseq: A genome-guided in silico approach to identifying tumor neoantigens. Genome Medicine. 2016, 8:11, DOI: 10.1186/s13073-016-0264-5. PMID: 26825632.

- [VEP](https://www.ensembl.org/info/docs/tools/vep/index.html)

  > McLaren W, Gil L, Hunt SE, Riat HS, Ritchie GR, Thormann A, Flicek P Cunningham F. The Ensembl Variant Effect Predictor. Genome Biology Jun 6;17(1):122. (2016) doi:10.1186/s13059-016-0974-4

- [vcf2maf](https://github.com/mskcc/vcf2maf)

  > Cyriac Kandoth. mskcc/vcf2maf: vcf2maf v1.6. (2020). doi:10.5281/zenodo.593251