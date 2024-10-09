## Introduction

**nf-core/pvacseq** is a bioinformatics pipeline that transforms MAF files to VCF, annotates them with VEP, and analyzes them with pVACseq to facilitate the investigation of neoantigens.

<!-- TODO nf-core:
   Complete this sentence with a 2-3 sentence summary of what types of data the pipeline ingests, a brief overview of the
   major pipeline sections and the types of output it produces. You're giving an overview to someone new
   to nf-core here, in 15-20 seconds. For an example, see https://github.com/nf-core/rnaseq/blob/master/README.md#introduction
-->

<!-- TODO nf-core: Include a figure that guides the user through the major workflow steps. Many nf-core
     workflows use the "tube map" design for that. See https://nf-co.re/docs/contributing/design_guidelines#examples for examples.   -->
<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->

1. Maf to vcf. 
2. Annotate vcf with VEP that pVACseq tool need.
3. Use pVACseq tool to get potential neoantigens.

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

<!-- TODO nf-core: Describe the minimum required steps to execute the pipeline, e.g. how to prepare samplesheets.
     Explain what rows and columns represent. For instance (please edit as appropriate):

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fastq_1,fastq_2
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz
```

Each row represents a fastq file (single-end) or a pair of fastq files (paired end).

-->
First, you need to have 
1. Directory with *.maf files
2. Directory with HLA information. Now the format require to have directory with folders of tumour sample name and `hla_types.txt` file that contain information about HLA. 

For example:
`/path/to/hla/TCGA-AF-2687-01A-02D-1733-10/hla_types.txt`

Now, you can run the pipeline using:

<!-- TODO nf-core: update the following command to include all required parameters for a minimal example -->

```bash
nextflow run main.nf \
   -profile <conda> \
   --input <MAF DIRECTORY> \
   --hla_directory <HLA DIRECTORY> \
   --outdir <OUTDIR>
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