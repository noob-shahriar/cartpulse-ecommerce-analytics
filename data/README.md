# Data

## Source
[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle).
Real, anonymised orders placed at Olist stores in Brazil, Sept 2016 - Oct 2018 (about 100k orders, 9 tables).
Please check the Kaggle page for the dataset licence before reusing the data.

## Folders
| Folder | Contents | In git? |
|---|---|---|
| `raw/` | The 9 original CSVs, **never modified** | No (about 125 MB, download from Kaggle) |
| `processed/` | Cleaned tables produced by `scripts/data_pipeline.py` | No, regenerated. Small samples in `processed/samples/` |

## How to obtain the raw data
1. Download `archive.zip` from the Kaggle page above.
2. Unzip the 9 CSV files into `data/raw/`.
3. Run `python scripts/data_pipeline.py` to create `data/processed/`.

See [`docs/data_dictionary.md`](../docs/data_dictionary.md) for every table and column.
