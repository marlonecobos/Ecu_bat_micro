#!/bin/bash

# before running make sure that the following files are present: mapping.tsv, all the barcodeXX.bam files contained in dorado_sup_out

#create working directories
mkdir -p datasets_out/
mkdir -p minimap_out/
mkdir -p samtools_filter_out/
mkdir -p samtools_fastq_out/

#create working environment
conda create --name ecu_bat_micro
conda activate ecu_bat_micro

#download bioconda and conda forge
conda config --add channels bioconda
conda config --add channels conda-forge
conda config --set channel_priority strict

#install ncbi installer, minimap2 and samtools
conda install -c conda-forge ncbi-datasets-cli -c bioconda minimap2 samtools

# translate .bam files to .fastq files
for i in $(seq -w 01 24)
  do
    barcode="barcode${i}"
    samtools fastq dorado_sup_out/barcode${i}.bam > samtools_fastq_out/barcode${i}.fastq
done

#download reference genomes 
# An array of accession numbers
ACCESSIONS=(
    "GCA_004027475.1"
    "GCA_004027735.1"
    "GCA_014824575.3"
    "GCA_027563665.1"
    "GCA_027574615.1"
    "GCA_036850765.1"
    "GCA_038363175.3"
    "GCA_039880945.1"
    "GCA_963259705.2"
)

# Loop through the accession numbers and download/unzip each one
for acc in "${ACCESSIONS[@]}"; do
    echo "Downloading and unzipping ${acc}"
    datasets download genome accession "${acc}" --include genome,seq-report --filename "${acc}.zip"
    unzip "${acc}.zip" -d "datasets_out/${acc}"
    echo "Done with ${acc}"
done

#Host Sequence Filtering
# Declare an associative array
declare -A barcode_map

# Read mapping from TSV file
while IFS=$'\t' read -r barcode _ _ _ genome_code _; do
    barcode_map[$barcode]=$genome_code
done < mapping.tsv 

# Loop through barcode numbers
for i in $(seq -w 01 24); do
    barcode="barcode${i}"
    genome_code=${barcode_map[$barcode]}
    
    # Check if the barcode has a genome code mapping
    if [ -n "$genome_code" ]; then
        echo "Processing $barcode with $genome_code"
        minimap2 -a -x lr:hq datasets_out/${genome_code}/ncbi_dataset/data/${genome_code}/${genome_code}*.fna \
            samtools_fastq_out/${barcode}.fastq | \
            samtools view -bh | \
            samtools sort -o minimap_out/${barcode}.bam
    else
        echo "No genome code found for $barcode, skipping..."
    fi
done

#filter the non-host sequences
for i in $(seq -w 01 24)
  do
    barcode="barcode${i}"
samtools fastq -f 4 minimap_out/barcode${i}.bam | samtools sort -o samtools_filter_out/barcode${i}.fastq  # try running in paralell
done