import argparse
import base64
import os
import sys

import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import pandas as pd
import seaborn as sns

BAR_COLOR = "#B22222"
CMAP = LinearSegmentedColormap.from_list(
    "white_yellow_red", ["white", "#FFFF00", "#FF8000", "#CC0000"]
)


def save_figure(fig, out_dir: str, filename: str):
    path = os.path.join(out_dir, filename)
    fig.savefig(path, dpi=150, bbox_inches="tight")
    print(f"Saved: {path}")
    plt.close(fig)


def load_filtered_files(file_paths: list[str], sample_names: list[str]) -> pd.DataFrame:
    dfs = []
    for file_path, name in zip(file_paths, sample_names):
        if not os.path.exists(file_path):
            print(f"Warning: {file_path} not found, skipping.", file=sys.stderr)
            continue
        df = pd.read_csv(file_path, sep='\t', low_memory=False)
        df['Patient_Short'] = name[:25]
        dfs.append(df)
    if not dfs:
        return pd.DataFrame()
    return pd.concat(dfs, ignore_index=True)


def plot_neoantigen_distribution(df: pd.DataFrame, out_dir: str, top_n: int = 30):
    """Boxplot: per-patient neoantigen count distribution for the top N genes."""
    counts = (
        df.groupby(['Gene Name', 'Patient_Short'])
        .size()
        .reset_index(name='count')
    )
    top_genes = (
        counts.groupby('Gene Name')['count']
        .sum()
        .sort_values(ascending=False)
        .head(top_n)
        .index
    )
    counts = counts[counts['Gene Name'].isin(top_genes)]
    gene_order = (
        counts.groupby('Gene Name')['count']
        .median()
        .sort_values(ascending=False)
        .index
    )
    fig, ax = plt.subplots(figsize=(20, 8))
    sns.boxplot(
        data=counts, x='Gene Name', y='count', order=gene_order, ax=ax,
        color='#A7B4C8', width=0.7,
        flierprops=dict(marker='o', markerfacecolor='#3C3C3C', markeredgecolor='#3C3C3C', markersize=3, alpha=0.9),
    )
    sns.stripplot(
        data=counts, x='Gene Name', y='count', order=gene_order, ax=ax,
        color='#3C3C3C', size=3, jitter=0.12, alpha=0.6,
    )
    ax.set_title(f"Per-Patient Neoantigen Count Distribution — Top {top_n} Genes", fontsize=24, fontweight='normal', pad=20)
    ax.set_xlabel("Gene", fontsize=22)
    ax.set_ylabel("No. of neoantigens per patient", fontsize=22)
    ax.tick_params(axis='x', rotation=90, labelsize=13)
    ax.tick_params(axis='y', labelsize=13)
    ax.grid(True, axis='y')
    fig.tight_layout()
    save_figure(fig, out_dir, "per_patient_neoantigen_count_distribution.png")


def plot_top_genes(df: pd.DataFrame, out_dir: str, top_n: int = 30):
    """Bar chart: top N genes by total neoantigen count."""
    counts = df['Gene Name'].value_counts().head(top_n)
    fig, ax = plt.subplots(figsize=(20, 8))
    counts.plot(kind='bar', ax=ax, color=BAR_COLOR, edgecolor='white')
    ax.set_title(f"Top {top_n} Genes by Neoantigen Count", fontsize=24, fontweight='normal', pad=20)
    ax.set_xlabel("Gene", fontsize=22)
    ax.set_ylabel("No. of neoantigens", fontsize=22)
    ax.tick_params(axis='x', rotation=90, labelsize=14)
    ax.tick_params(axis='y', labelsize=13)
    ax.grid(True, axis='both')
    fig.tight_layout()
    save_figure(fig, out_dir, "top_genes_by_neoantigen_count.png")


def plot_mutation_vs_hla(
    df: pd.DataFrame,
    out_dir: str,
    filename: str,
    top_alleles: int = 25,
    top_mutations: int = 15,
    annotate: bool = False,
):
    """Heatmap: relative neoantigen frequency by mutation and HLA allele."""
    sub = df[['Gene Name', 'Mutation', 'Protein Position', 'HLA Allele']].dropna()
    if sub.empty:
        return

    sub = sub.copy()
    wt = sub['Mutation'].str.split('/').str[0]
    mt = sub['Mutation'].str.split('/').str[1]
    sub['MutationLabel'] = sub['Gene Name'] + ' ' + wt + sub['Protein Position'].astype(str) + mt

    top_hla = sub['HLA Allele'].value_counts().head(top_alleles).index
    sub = sub[sub['HLA Allele'].isin(top_hla)]

    top_mut = sub['MutationLabel'].value_counts().head(top_mutations).index
    sub = sub[sub['MutationLabel'].isin(top_mut)]

    pivot = sub.groupby(['MutationLabel', 'HLA Allele']).size().unstack(fill_value=0)
    if pivot.empty:
        return

    pivot = pivot / len(df)

    row_order = pivot.sum(axis=1).sort_values(ascending=False).index
    col_order = pivot.sum(axis=0).sort_values(ascending=False).index
    pivot = pivot.loc[row_order, col_order]

    fig_h = max(10, len(pivot) * 0.6 + 2)
    fig_w = max(14, len(pivot.columns) * 0.5)
    fig, ax = plt.subplots(figsize=(fig_w, fig_h))
    sns.heatmap(
        pivot, ax=ax, cmap=CMAP,
        linewidths=0.6, linecolor='#C8C8C8',
        annot=annotate, fmt='.4f' if annotate else '',
        cbar_kws={'label': 'Neoantigen frequency'},
    )
    if annotate:
        ax.set_title(
            f"Mutation x Top {top_alleles} HLA Alleles — Annotated Frequency",
            fontsize=24, fontweight='normal', pad=20,
        )
    else:
        ax.set_title(
            f"Mutation x HLA Alleles — Top {top_mutations} Mutations, Top {top_alleles} Alleles",
            fontsize=24, fontweight='normal', pad=20,
        )
    ax.set_xlabel("HLA allele", fontsize=20)
    ax.set_ylabel("Mutation", fontsize=20)
    ax.tick_params(axis='x', rotation=90, labelsize=11)
    ax.tick_params(axis='y', rotation=0, labelsize=11)
    fig.tight_layout()
    fig.subplots_adjust(bottom=0.28)
    save_figure(fig, out_dir, filename)


def plot_chromosome_distribution(df: pd.DataFrame, out_dir: str):
    """Boxplot: per-patient neoantigen count per chromosome."""
    sub = df[['Chromosome', 'Patient_Short']].dropna()
    if sub.empty:
        return
    counts = sub.groupby(['Patient_Short', 'Chromosome']).size().reset_index(name='count')

    counts['ChromosomeCore'] = (
        counts['Chromosome']
        .astype(str)
        .str.replace(r'^chr', '', case=False, regex=True)
    )

    chrom_order = [str(i) for i in range(1, 23)] + ['X', 'Y', 'MT']
    present = [c for c in chrom_order if c in counts['ChromosomeCore'].unique()]
    extra = sorted(set(counts['ChromosomeCore'].unique()) - set(chrom_order))
    order_core = present + extra

    counts['ChromosomeLabel'] = 'chr' + counts['ChromosomeCore']
    order_labels = ['chr' + c for c in order_core]

    fig, ax = plt.subplots(figsize=(20, 10))
    sns.boxplot(
        data=counts, x='ChromosomeLabel', y='count', order=order_labels, ax=ax,
        color='#A7B4C8', width=0.8,
        flierprops=dict(marker='o', markerfacecolor='#3C3C3C', markeredgecolor='#3C3C3C', markersize=3, alpha=0.9),
    )
    sns.stripplot(
        data=counts, x='ChromosomeLabel', y='count', order=order_labels, ax=ax,
        color='#3C3C3C', size=3, jitter=0.12, alpha=0.75,
    )
    ax.set_title("Neoantigens per Chromosome across Patients", fontsize=30, fontweight='normal', pad=20)
    ax.set_xlabel("Chromosome", fontsize=22)
    ax.set_ylabel("Neoantigen Count per Patient", fontsize=22)
    ax.tick_params(axis='x', rotation=45, labelsize=15)
    ax.tick_params(axis='y', labelsize=15)
    fig.tight_layout()
    save_figure(fig, out_dir, "chromosome_neoantigen_boxplot.png")


def _encode_image(path: str) -> str:
    with open(path, "rb") as fh:
        return base64.b64encode(fh.read()).decode()


def write_multiqc_yaml(out_dir: str):
    plot_files = [
        "per_patient_neoantigen_count_distribution.png",
        "top_genes_by_neoantigen_count.png",
        "mutation_vs_all_hla_alleles.png",
        "mutation_vs_top_hla_alleles_annotated.png",
        "chromosome_neoantigen_boxplot.png",
    ]
    img_tags = [
        f'<img src="data:image/png;base64,{_encode_image(os.path.join(out_dir, f))}"'
        f' style="max-width:100%;display:block;margin-bottom:1em;"/>'
        for f in plot_files
        if os.path.exists(os.path.join(out_dir, f))
    ]
    html = "".join(img_tags)

    with open("summary_plots_mqc.yaml", "w") as fh:
        fh.write(
            'id: "nextflow-pvacseq-summary"\n'
            'section_name: "Summary"\n'
            'plot_type: "html"\n'
            'data: |\n'
            + "".join(f"  {line}\n" for line in html.splitlines())
        )
    print("Saved: summary_plots_mqc.yaml")


def main():
    parser = argparse.ArgumentParser(description="Generate pVACseq summary plots.")
    parser.add_argument('--filtered-files', nargs='+', required=True, help="Paths to .filtered.tsv files")
    parser.add_argument('--sample-names', nargs='+', required=True, help="Sample names per file")
    parser.add_argument('--out-dir', default='figures', help="Output directory for plots")
    args = parser.parse_args()

    sns.set_theme(style="darkgrid")
    plt.rcParams['grid.alpha'] = 0.8
    plt.rcParams['grid.linewidth'] = 0.8
    plt.switch_backend('Agg')

    os.makedirs(args.out_dir, exist_ok=True)
    df = load_filtered_files(args.filtered_files, args.sample_names)
    if df.empty:
        print("No data loaded. Exiting.", file=sys.stderr)
        sys.exit(1)

    plot_neoantigen_distribution(df, args.out_dir)
    plot_top_genes(df, args.out_dir)
    plot_mutation_vs_hla(df, args.out_dir, "mutation_vs_all_hla_alleles.png",
                         top_alleles=25, top_mutations=15, annotate=False)
    plot_mutation_vs_hla(df, args.out_dir, "mutation_vs_top_hla_alleles_annotated.png",
                         top_alleles=8, top_mutations=15, annotate=True)
    plot_chromosome_distribution(df, args.out_dir)
    write_multiqc_yaml(args.out_dir)


if __name__ == '__main__':
    main()
