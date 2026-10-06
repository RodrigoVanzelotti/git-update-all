# git-update-all

Updates every Git repo in the current folder to the same branch

## Usage

Run from the folder that **contains** your repos (not from inside a repo):

```powershell
git-update-all                      # maps checkout to main
git-update-all feature/my-feature   # maps checkout to feature/my-feature in every repo
```

To use like the example below, add the script to a folder like `C:/Scripts` and add this path to your **System Path**.
You can set it up to git to use with a git alias on Windows. I didn't adapted it to Linux, feel free to.

```powershell
git config --global alias.update-all "!powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/Scripts/git-update-all.ps1
```

Then you can use as:

```powershell
git update-all                      # maps checkout to main
git update-all feature/my-feature   # maps checkout to feature/my-feature in every repo
```
