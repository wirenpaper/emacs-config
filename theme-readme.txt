If a year from now you discover a new favorite theme and you want to commit it so it becomes the new default for all your machines, you simply reverse the command:

Bash
git update-index --no-skip-worktree local-theme.el
git commit -am "Update default theme to ef-spring"
git update-index --skip-worktree local-theme.el
