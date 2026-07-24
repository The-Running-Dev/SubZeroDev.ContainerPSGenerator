# Repository workflow

When the user says **"do next todo"**, perform this workflow autonomously:

1. If the current branch has an open pull request, inspect its checks and unresolved
   review threads first. Address actionable Copilot comments, test and push the fixes,
   wait for required checks, resolve the addressed threads, merge the pull request,
   and confirm it is closed.
2. Preserve unrelated and uncommitted user work. Never stage, reset, clean, or
   overwrite it. In particular, treat dirty submodules as user-owned work.
3. Fetch and safely synchronize the superproject with `origin/main`.
4. Read `TODO.md`, inspect the relevant current implementation, and select the first
   unchecked, actionable Version 1 item unless the user names another item.
5. Implement the smallest complete reviewable slice on a new `feature/` branch.
6. Update tests and documentation or `TODO.md` when the behavior or roadmap changes.
7. Run the full relevant local test suite.
8. Commit only task-related files, push the branch, and open a non-draft pull request.
9. Watch GitHub Actions to completion. Inspect Copilot review threads, address all
   actionable feedback, rerun validation, push fixes, and resolve addressed threads.
10. Merge the pull request only when it is mergeable, required checks pass, and no
    actionable review threads remain. Confirm the pull request is closed.

Use concise progress updates. Report the selected TODO item, test results, pull
request URL, merge commit, and any work that remains intentionally untouched.

## Documentation generation

When the user says **"generate documentation"**, use this prompt:

> Generate or refresh the project documentation from the current implementation.
> Treat source code, public command help, specifications, tests, examples, workflows,
> and TODOs as the source of truth. First inspect the existing Docusaurus layout,
> then write concise Markdown with front matter, ordered categories, working relative
> links, runnable examples, explicit support boundaries, and no invented behavior.
> Cover getting started, guides, reference, architecture, development, releases,
> security, and troubleshooting as applicable. Preserve unrelated work. Validate
> front matter, category JSON, local links, the Docusaurus production build, and the
> relevant repository quality and test suites before committing.

Invoke the complete workflow with **"generate documentation"**. To limit its scope,
append a subject, for example: **"generate documentation for runtime mappings"**.
