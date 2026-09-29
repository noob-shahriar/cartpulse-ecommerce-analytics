# Running CartPulse in VS Code - A Beginner's Guide

This guide assumes you have **never** set up a data project before. Follow it top to bottom, in order. Steps are written for **Windows** (most common) with a macOS note wherever a step differs. It takes about 45-60 minutes the first time.

You will install 5 things (VS Code, Python, Git, PostgreSQL, and two VS Code extensions), then load the project and run it.

---

## Part 1 - Install the tools

### 1.1 Install VS Code
1. Go to https://code.visualstudio.com/
2. Click the big blue **Download** button.
3. Run the installer. Accept the defaults and click through to **Finish**. Leave "Launch Visual Studio Code" checked.

### 1.2 Install Python
1. Go to https://www.python.org/downloads/ and click **Download Python 3.12** (or newer).
2. Run the installer.
3. **Important:** on the first screen, tick the checkbox at the bottom that says **"Add python.exe to PATH"** before clicking Install. This is the single most common beginner mistake - if you skip it, nothing else in this guide will work.
4. Click **Install Now** and let it finish.
5. Check it worked: open VS Code, then open a terminal inside it (menu **Terminal > New Terminal**, or `` Ctrl+` ``). Type:
   ```
   python --version
   ```
   You should see something like `Python 3.12.x`. If you see an error, restart your computer and try again (PATH changes need a restart on Windows).

### 1.3 Install Git
1. Go to https://git-scm.com/downloads and download Git for your OS.
2. Run the installer - the defaults are fine for every screen, just keep clicking **Next** then **Install**.
3. Check it worked, in the same VS Code terminal:
   ```
   git --version
   ```

### 1.4 Install PostgreSQL
This is the database that stores CartPulse's cleaned data so SQL can query it.
1. Go to https://www.postgresql.org/download/ and pick your OS (Windows: use the EDB installer link).
2. Run the installer.
3. When it asks for a **password for the postgres superuser**, type one and **write it down** - you'll need it in a moment. (Any password is fine for a local learning project, e.g. `postgres123`.)
4. Keep the default **port 5432**.
5. When it offers to launch **Stack Builder** at the end, you can click **Cancel/Skip** - you don't need it.
6. Check it worked: in the VS Code terminal:
   ```
   psql --version
   ```
   If `psql` isn't recognised on Windows, search your Start Menu for **"SQL Shell (psql)"** instead - PostgreSQL's own terminal - and use that for the database steps in Part 3.

### 1.5 Install two VS Code extensions
Inside VS Code, click the **Extensions** icon in the left sidebar (looks like 4 squares), then:
1. Search **"Python"** (by Microsoft) → click **Install**.
2. Search **"Jupyter"** (by Microsoft) → click **Install**.

That's it for setup. Everything else happens inside VS Code.

---

## Part 2 - Get the project into VS Code

You have a file called `CartPulse.bundle`. This is a compressed copy of the whole project with its full history, made because the environment that built it couldn't log in to your GitHub directly.

1. Create a folder somewhere easy to find, e.g. `C:\Projects\`.
2. Move `CartPulse.bundle` into that folder.
3. Open that folder in VS Code: **File > Open Folder...** → select `C:\Projects\`.
4. Open a terminal in VS Code (`` Ctrl+` ``) and run:
   ```
   git clone CartPulse.bundle CartPulse
   ```
   This creates a new folder `CartPulse` with the full project and all 15 commits.
5. Now open **that** folder properly: **File > Open Folder...** → select `C:\Projects\CartPulse`. VS Code will reload with the project as your workspace - you'll see folders like `data`, `sql`, `notebooks`, `scripts` in the Explorer panel on the left.

### 2.1 Connect it to your real GitHub repo (optional, do this now or later)
In the VS Code terminal:
```
cd C:\Projects\CartPulse
git remote set-url origin https://github.com/noob-shahriar/cartpulse-ecommerce-analytics.git
git push -u origin main
```
The first time you push, VS Code or Windows will pop up a window asking you to log in to GitHub - sign in there. After that, all 15 commits appear on GitHub.

---

## Part 3 - Set up the project to actually run

### 3.1 Create a virtual environment
A virtual environment keeps this project's Python packages separate from everything else on your computer. In the VS Code terminal, **make sure you're inside the `CartPulse` folder**, then:
```
python -m venv venv
```
This creates a `venv` folder (already gitignored, so it won't get committed). Now activate it:
- **Windows:** `venv\Scripts\activate`
- **macOS/Linux:** `source venv/bin/activate`

You'll know it worked because your terminal prompt now starts with `(venv)`. **Do this every time you open a new terminal for this project.**

If VS Code shows a popup "Select Python Interpreter" or similar, choose the one that says `venv` / `.\venv\Scripts\python.exe`.

### 3.2 Install the required Python packages
Still in the `(venv)` terminal:
```
pip install -r requirements.txt
pip install jupyter nbformat ipykernel
```
This installs pandas, numpy, matplotlib, seaborn, psycopg2 (talks to PostgreSQL), and Jupyter (runs notebooks). This step can take a couple of minutes.

### 3.3 Get the raw dataset
The raw data isn't included in the project (it's a licensed Kaggle dataset, ~125 MB, so it's intentionally left out).
1. Go to https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
2. You'll need a free Kaggle account to download. Click **Download** (downloads a file called `archive.zip`).
3. Unzip it - you should see 9 files ending in `.csv`.
4. Copy all 9 CSV files into the project's `data\raw\` folder (in VS Code's Explorer panel, right-click the `raw` folder → **Reveal in File Explorer** to find it easily, or just drag the files from your Downloads folder directly into that folder in VS Code's Explorer panel).

### 3.4 Create your database
Open the VS Code terminal (or Windows' "SQL Shell (psql)" app if `psql` wasn't found earlier) and connect as the postgres superuser:
```
psql -U postgres
```
It will ask for the password you set during install. Once you see a `postgres=#` prompt, run these three lines (press Enter after each):
```sql
CREATE USER cartpulse WITH PASSWORD 'cartpulse123' SUPERUSER;
CREATE DATABASE cartpulse OWNER cartpulse;
\q
```
`\q` quits back to your normal terminal.

### 3.5 Tell the project how to reach your database
In VS Code's Explorer, find the file `.env.example` in the project root, right-click it → **Copy**, then right-click the empty space below it → **Paste**, and rename the copy to `.env` (this file is gitignored - it never gets committed, which is correct since it can hold a password). Open `.env` and edit it to match what you set in step 3.4:
```
PGHOST=localhost
PGPORT=5432
PGDATABASE=cartpulse
PGUSER=cartpulse
PGPASSWORD=cartpulse123
```

Now, in your `(venv)` terminal, load those values into the terminal session:
- **Windows (PowerShell):**
  ```
  Get-Content .env | ForEach-Object { if ($_ -match '^(.*?)=(.*)$') { [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2]) } }
  ```
- **macOS/Linux:**
  ```
  export $(cat .env | xargs)
  ```
(You'll need to redo this each time you open a fresh terminal - or just set `PGPASSWORD` etc. as permanent Windows/macOS environment variables if you don't want to repeat this.)

### 3.6 Run the pipeline
Still in your `(venv)` terminal, one command at a time:
```
python scripts/data_pipeline.py
```
This cleans the raw data - you should see 8 lines like `orders_clean    98,199 rows`.
```
python scripts/setup_database.py
```
This creates the database tables and loads the cleaned data into PostgreSQL - you should see it load 9 tables.
```
python scripts/run_sql.py
```
This runs all 8 SQL analysis files and saves the results as CSVs into `reports/sql_results/`.

If any of these show a red error instead of the expected output, see **Troubleshooting** at the bottom.

---

## Part 4 - Explore the results

### 4.1 Open a notebook
In VS Code's Explorer, click `notebooks/03_exploratory_analysis.ipynb`. It opens as a notebook (you can see the charts and text already there from when it was built). At the top-right, VS Code will show a **Select Kernel** button - click it, then choose your `venv` Python environment. Now you can click the **Run All** button at the top to re-run everything yourself, or click into any individual cell and press `Shift+Enter` to run just that one.

### 4.2 Browse the SQL results
Open any file in `reports/sql_results/` (they're plain CSVs) - VS Code will show them as a simple table if you have a CSV viewer, or you can open them in Excel.

### 4.3 Read the write-ups
`reports/executive_summary.md` and `reports/business_recommendations.md` are the plain-English findings; open them in VS Code and use **Ctrl+Shift+V** to see them nicely formatted instead of raw text.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `'python' is not recognized` | Python wasn't added to PATH. Reinstall Python and tick "Add python.exe to PATH", then restart your computer. |
| `'psql' is not recognized` | Use the Start Menu app **"SQL Shell (psql)"** instead, or add PostgreSQL's `bin` folder (something like `C:\Program Files\PostgreSQL\16\bin`) to your PATH manually. |
| `psycopg2.OperationalError: connection ... refused` | PostgreSQL isn't running. On Windows, search Start Menu for **Services**, find **postgresql-x64-16**, right-click → **Start**. |
| `psycopg2.OperationalError: password authentication failed` | Your `.env` password doesn't match what you set in step 3.4. Re-check both. |
| `ModuleNotFoundError: No module named 'pandas'` (or similar) | Your terminal isn't using the `venv`. Run the activate command from step 3.1 again - check your prompt starts with `(venv)`. |
| Notebook's "Select Kernel" doesn't show your venv | Close and reopen VS Code after creating the venv, or run `pip install ipykernel` again inside the activated venv. |
| `git push` asks for a password and rejects it | GitHub no longer accepts plain passwords for `git push`. Let the VS Code/Windows sign-in popup handle it, or set up a Personal Access Token / SSH key via GitHub's own docs. |

If you get stuck on any single step, tell me exactly what error message you see (copy-paste it) and I'll help you fix that specific one.
