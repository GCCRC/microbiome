# Parse by SRAdb

## Installation 
# if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
# BiocManager::install("SRAdb")

#### Setting things up ####

# [.. Libraries ..] #

library("SRAdb")
library("data.table")

# [.. Links .. ] #
# https://www.sqlitetutorial.net/sqlite-full-text-search/

## Get the db!
getSRAdbFile(destdir = getwd(), destfile = "./data/SRAmetadb.sqlite.gz", "auto")

## Add the file as object
sqlfile = file.path(system.file('extdata', package="SRAdb"), "./data/SRAmetadb.sqlite.")
file.info("./data/SRAmetadb.sqlite")
  
#### Generating data tables ####
sra_con = dbConnect(SQLite(),"./data/SRAmetadb.sqlite")
sra_tables = dbListTables(sra_con)

## Check all DBs
sra_tables

## Check SRA fields
dbListFields(sra_con, "sra")

## Check SRA schema
dbGetQuery(sra_con, 'PRAGMA TABLE_INFO(sra)')

## Get column descriptions
colDesc = colDescriptions(sra_con=sra_con)[1:10,]


#### Making SQL queries ####

#### Q1. 15000 first SRA entries ####
query_test = data.table(dbGetQuery(sra_con, "select * from sra limit 15000"))

#### Q2. Get all transcriptomes ####
query02_all_transcriptomes = data.table(
  dbGetQuery(
    sra_con, paste(
      "select study_accession, study_title from sra where",
      "study_description like 'Transcriptome%'", sep = " "
    )
  )
)

#### Q3. Studies and study types ####
query03_study_types = data.table(dbGetQuery(
  conn = sra_con,
  statement = paste(
    "SELECT study_type 
    AS StudyType,
    count ( * ) 
    AS Number 
    FROM `sra` 
    GROUP BY study_type
    order by Number DESC ",
    sep = ""
  )
))

#### Q4. List all libraries and library strategies ####
query04_strategies = data.table(dbGetQuery(
  sra_con,
  paste(
    "SELECT library_strategy
    AS 'Library Strategy',
    count ( * ) AS Runs
    FROM `experiment`
    GROUP BY library_strategy
    order by Runs DESC",
    sep = ""
  )))


#### Text search & mining ####

#### S1. Breast cancer? ####
SR01 = data.table(getSRA(
  search_terms = "breast cancer",
  out_types = c('run', 'study'),
  sra_con
))

#### S2. OR Connector ####
SR02 = data.table(getSRA(
  search_terms = 'Metagenomics
    OR Metatranscriptomics
    OR Transcriptomic
    OR Transcriptomics
    OR Metatranscriptome
    OR Metagenome
    OR Drought
    OR Salt
    OR Salinity
    OR Dry
    NOT "Homo sapiens" 
    NOT "Mus musculus"
    NOT "Arabidopsis thaliana"
    NOT "Caenorhabditis elegans"
    NOT "Gallus gallus"
    NOT "Cancer"
    NOT "Tumor"
    NOT "RAD-Seq"
    NOT "Amplicon"
    NOT "Metabarcoding"
    NOT "Chip-Seq"',
  out_types = c('run', 'study'),
  sra_con
))

#### S3. Stringent - does NOT works? ####
SR03 = data.table(getSRA(
  search_terms = "Metagenomics NOT Amplicon",
  out_types = c('run', 'study'),
  sra_con
))


SR03.alt = data.table(getSRA(
  search_terms = "Metagenomics",
  out_types = c('run', 'study'),
  sra_con
))

SR03.plus = data.table(getSRA(
  search_terms = "Metagenomics 
  OR Metatranscriptomics 
  NOT Amplicon 
  OR Homo sapiens",
  out_types = c('run', 'study'),
  sra_con
))


# It does!
# Now, let's test AND

SR03.and = data.table(getSRA(
  search_terms = 'Drought NOT "Zea mays"',
  out_types = c('run', 'study'),
  sra_con
))


#### S4. Oh, Largest One ####

SR04 = data.table(getSRA(
  search_terms = 'Metagenomics
    OR Metatranscriptomics
    OR Transcriptomic
    OR Transcriptomics
    OR Metatranscriptome
    OR Metagenome
    OR Drought
    OR Salt
    OR Salinity
    OR Dry
    OR "Wet up"
    OR "Dry up"
    OR "Dried"
    OR "Osmotic"
    NOT "Homo sapiens" 
    NOT "Mus musculus"
    NOT "Arabidopsis thaliana"
    NOT "Caenorhabditis elegans"
    NOT "Gallus gallus"
    NOT "Cancer"
    NOT "Tumor"
    NOT "RAD-Seq"
    NOT "Amplicon"
    NOT "Metabarcoding"',
  out_types = c('run', 'study'),
  sra_con
))


#### S5. Stepwise query ####


#### New strategy: one per term ####
# Rationale
# Max out negative filters
# Query positive filters one per turn

new.q01.transcriptomics = data.table(getSRA(
  search_terms = 'Transcriptomics
  NOT Metabarcoding
  NOT "Homo sapiens"
  NOT "Mus musculus"
  NOT "Gallus gallus"
  NOT "activated sludge"
  NOT "wastewater"
  NOT "Wastewater"
  NOT Amplicon
  NOT Tumor
  NOT Cancer',
  out_types = c('sample', 'run'),
  sra_con
))

new.q02.metatranscriptomics = data.table(getSRA(
  search_terms = '(metatranscriptomics OR metatranscriptome)
  NOT Metabarcoding
  NOT "Homo sapiens"
  NOT "Mus musculus"
  NOT "Gallus gallus"
  NOT "activated sludge"
  NOT "wastewater"
  NOT "Wastewater"
  NOT Amplicon
  NOT Tumor
  NOT Cancer',
  out_types = c('sample', 'run'),
  sra_con
))

new.q03.metagenomes = data.table(getSRA(
  search_terms = '(metagenomics OR metagenome)
  NOT Metabarcoding
  NOT "Homo sapiens"
  NOT "Mus musculus"
  NOT "Gallus gallus"
  NOT "activated sludge"
  NOT "wastewater"
  NOT "Wastewater"
  NOT Amplicon
  NOT Tumor
  NOT Cancer',
  out_types = c('sample', 'run'),
  sra_con
))

#### One search to rule them all ####
new.q04.allterms = data.table(getSRA(
  search_terms = '(metagenomics OR metagenome OR metatranscriptome OR metatranscriptomics OR transcriptomics OR transcriptome OR single-cell OR Single-cell)
  AND Drought OR Dry OR Salt OR Osmotic OR "Dry up" OR "Wet up" OR "Salinity"
  NOT Metabarcoding
  NOT "Homo sapiens"
  NOT "Mus musculus"
  NOT "Gallus gallus"
  NOT "activated sludge"
  NOT "wastewater"
  NOT "Wastewater"
  NOT Amplicon
  NOT Tumor
  NOT Cancer',
  out_types = c('sample', 'run', 'study'),
  sra_con
))


## After reading!
new.q05.no.transcriptome = data.table(getSRA(
  search_terms = '(metagenomics OR metagenome OR metatranscriptome OR metatranscriptomics OR transcriptome)
  AND (Drought OR Dry OR Salt OR Salinity OR Osmotic OR Heat OR "Wet up" OR Rehydrated OR Hydrated)
  NOT ("Homo sapiens" OR "Mus musculus" OR "Gallus gallus")
  NOT "activated sludge"
  NOT "wastewater"
  NOT "Tara oceans"
  NOT (454 OR Metabarcoding OR Amplicon)',
  out_types = c('sra','submission','study','sample','experiment','run'),
  sra_con
))


#### Checking up some stats. ####

## How many per query? ##
size_Q05 = dim(data.table(getSRA(
  search_terms = '(metagenomics OR metagenome OR metatranscriptome OR metatranscriptomics OR transcriptome OR transcriptomics)
  AND (Dry OR Drought OR Salt OR Salinity OR Heat OR "Dry up" OR "Wetted" OR Hydrated OR Rehydrated OR "Wet up" OR Osmotic)
  NOT ("Homo sapiens" OR "Mus musculus" OR "Gallus gallus")
  NOT ("activated sludge" OR wastewater OR "Tara oceans")
  NOT (Amplicon OR Metabarcoding)',
  out_types = c('sra','submission','study','sample','experiment','run'),
  sra_con)))

#### SAVE your tables! ####

B19_table = data.table(getSRA(
  search_terms = '(transcriptome OR transcriptomics OR RNA-Seq)
  AND (Dry OR Drought OR Salt OR Salinity OR Heat OR "Dry up" OR "Wetted" OR Hydrated OR Rehydrated OR "Wet up" OR Osmotic OR "Heat shock" OR Stress)
  AND (Bacteria OR Fungi OR Archaea OR Algae OR Cyanobacteria OR Microbe OR Isolate)
  NOT ("Homo sapiens" OR "Mus musculus" OR "Gallus gallus" OR Neurons OR Macrophages OR 16S OR ITS OR Drug OR Antibiotic)
  NOT ("activated sludge" OR wastewater OR "Tara oceans" OR "rumen microbiome" OR Mouse OR Human OR Drosophila)
  NOT (Amplicon OR Metabarcoding OR Placenta OR Placental OR 454 OR Bioreactor OR "Drug resistance" OR "human gut")',
  out_types = c('sra','submission','study','sample','experiment','run'),
  sra_con))

B19_table = B19_table[,-c("spots", "read_spec", "run_alias",
                          "adapter_spec", "experiment_url_link", "run_date", "submission_ID",
                          "submission","submission_center","submission_lab","submission_date", "base_caller",
                          "quality_scorer", "number_of_levels", "experiment_ID", "experiment_alias",
                          "center_project_name", "run_url_link", "run_entrez_link", "run_attribute",
                          "sradb_updated", "related_studies", "study_entrez_link", "run_center",
                          "common_name", "anonymized_name", "experiment_name", "experiment",
                          "sequence_space", "multiplier", "qtype", "experiment_entrez_link")]

colnames(B14_table)

## Save a table to file (.TSV)
write.table(x = B19_table, file = "./results/B19_megamicrobes.tsv",
            quote = F, sep = "\t", eol = "\n", row.names = F)

#### What about Silicibacter pomeroyi? ####
test = data.table(getSRA(search_terms = 'PRJNA315758',
  out_types = c('sra','submission','study','sample','experiment','run'),
  sra_con))

print(test[,c("run", "experiment_title")], sep = '\t', row.names = F)

