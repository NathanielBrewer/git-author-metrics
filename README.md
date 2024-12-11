### Git Author Metrics

This bash script gathers information about a git author's commits. Give it a date range, an author, and a list of repos, and it'll output something like this:

Metric                          | Value
------------------------------  | ----------
Commits                         | 2
Average message length (chars)  | 45.50
Max message length (chars)      | 48
Min message length (chars)      | 43
Total lines added               | 81
Total lines removed             | 13

## Features
- Accumulate metrics accross all remote branches in the default remote for each repo.
- Commit hashes are compared to avoid duplicate counts
- Metrics:
   - Average, min, and max message length
   - Number of commits
   - Total lines added and removed

---

## Requirements

- Bash (4.0 or later)
- Git installed and accessible via the command line

---

## Installation

1. Clone or download the repository containing the script:
   ```bash
   git clone https://github.com/NathanielBrewer/git-author-metrics.git
   cd git-author-metrics
   ```

---

## Usage

Run the script by navigating to its parent folder and running:

```bash
bash git_author_metrics.sh <start-date> <end-date> <author-name> <repo1> [repo2 ... repoN]
```

### Arguments:
- **`<start-date>`**: Start date for analysis in `YYYY-MM-DD` format
- **`<end-date>`**: End date for analysis in `YYYY-MM-DD` format
- **`<author-name>`**: The Git author's name or email to analyze (case-sensitive)
- **`<repo1> [repo2 ... repoN]`**: Space-separated list of absolute paths to repos

### Example:
```bash
bash git_author_metrics.sh 2024-11-01 2024-11-30 gitAuthorName ~/projects/my-repo ~/projects/my-other-repo
```

### Outputs
**Console table**   
The script outputs a summary table with the following metrics:

| Metric                          | Value  |
|---------------------------------|--------|
| Commits                         | Total number of commits in the given date range |
| Average message length (chars)  | Average length of commit messages |
| Max message length (chars)      | Length of the longest commit message |
| Min message length (chars)      | Length of the shortest commit message |
| Total lines added               | Total lines added across all commits |
| Total lines removed             | Total lines removed across all commits |

---

## Logging 

Log lines are just dumped into a file `./git_author_metrics.log`. There is no rollover or anything like that so the file might become very large if left unattented.

---

## How It Works

1. **Fetch Remotes**:
   - Fetches all branches for the default remote (`origin` or the first detected remote)

2. **Process Branches**:
   - Iterates through all branches of the default remote

3. **Process Commits**:
   - Identifies commits by the specified author in the given date range
   - Filters out duplicate commits and diffs to avoid double-counting lines

4. **Aggregate Metrics**:
   - Computes totals for lines added/removed and commit counts
   - Analyzes commit messages for maximum, minimum, and average lengths

## Contributing

Contributions are welcome! Follow these steps to contribute:

1. **Fork the repository** on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/NathanielBrewer/git-author-metrics.git
   ```
3. Create a new branch for your feature or fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. Make your changes and test thoroughly.
5. Commit your changes:   
  Please adhere to the [Convention Commit Messages format](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13) 
   ```bash
   git commit -m "feat: add another metric"
   ```
6. Push to your fork:
   ```bash
   git push -u origin your-feature-branch-name
   ```
7. Open a pull request to the main repository.

Please ensure your code adheres to Bash best practices and includes meaningful comments for maintainability.

---

## License

This project is licensed under the **MIT License**, which permits commercial use, modification, distribution, and private use, provided attribution is given to the original author.

---

## Feedback

If you encounter any issues or have suggestions for improvement, please open an issue in the [GitHub repository](https://github.com/NathanielBrewer/git-author-metrics/issues).