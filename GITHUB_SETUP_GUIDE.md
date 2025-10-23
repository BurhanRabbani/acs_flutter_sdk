# GitHub Repository Setup Guide
## Achieving Perfect 160/160 Pana Score for acs_flutter_sdk

**Current Status:** 140/160 points  
**Target:** 160/160 points (perfect score)  
**Points to Gain:** 20 points

---

## Why You're Losing 20 Points

### Issue 1: Repository URLs (10 points)
Your `pubspec.yaml` contains placeholder URLs:
- `homepage: https://github.com/yourusername/acs_flutter_sdk`
- `repository: https://github.com/yourusername/acs_flutter_sdk`
- `issue_tracker: https://github.com/yourusername/acs_flutter_sdk/issues`
- `documentation: https://github.com/yourusername/acs_flutter_sdk#readme`

### Issue 2: URLs Unreachable (10 points)
The placeholder URLs return 404 errors when pana tries to verify them.

---

## Solution: Create GitHub Repository and Update URLs

### Step 1: Create GitHub Repository

**Option A: Via GitHub Web Interface (Recommended)**

1. Go to https://github.com/new
2. Fill in the repository details:
   - **Repository name:** `acs_flutter_sdk`
   - **Description:** `Flutter plugin for Microsoft Azure Communication Services (ACS). Provides voice/video calling, chat, and identity management capabilities.`
   - **Visibility:** ✅ Public (required for pub.dev)
   - **Initialize repository:** ❌ Do NOT check "Add a README file" (we already have one)
   - **Add .gitignore:** ❌ Do NOT add (we already have one)
   - **Choose a license:** ❌ Do NOT add (we already have MIT license)
3. Click **"Create repository"**

**Option B: Via GitHub CLI**

```bash
gh repo create acs_flutter_sdk \
  --public \
  --description "Flutter plugin for Microsoft Azure Communication Services (ACS). Provides voice/video calling, chat, and identity management capabilities." \
  --source=. \
  --remote=origin
```

---

### Step 2: Initialize Local Git Repository

Run these commands in your terminal from the project directory:

```bash
# Initialize git repository
git init

# Configure git (if not already configured globally)
git config user.name "BurhanRabbani"
git config user.email "52907934+BurhanRabbani@users.noreply.github.com"

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Azure Communication Services Flutter SDK

- Complete Flutter plugin for Microsoft Azure Communication Services
- Native implementations for iOS (Swift) and Android (Kotlin)
- Voice/Video calling functionality
- Chat messaging functionality
- Identity management (server-side recommended)
- Comprehensive test suite (68 tests)
- Production-ready with 140/160 pana score
- Full documentation and examples"

# Add remote (replace BurhanRabbani with your GitHub username if different)
git remote add origin https://github.com/BurhanRabbani/acs_flutter_sdk.git

# Push to GitHub
git branch -M main
git push -u origin main
```

---

### Step 3: Update pubspec.yaml

The `pubspec.yaml` file has been automatically updated with the correct URLs.

**Changes made:**
```yaml
# Before:
homepage: https://github.com/yourusername/acs_flutter_sdk
repository: https://github.com/yourusername/acs_flutter_sdk
issue_tracker: https://github.com/yourusername/acs_flutter_sdk/issues
documentation: https://github.com/yourusername/acs_flutter_sdk#readme

# After:
homepage: https://github.com/BurhanRabbani/acs_flutter_sdk
repository: https://github.com/BurhanRabbani/acs_flutter_sdk
issue_tracker: https://github.com/BurhanRabbani/acs_flutter_sdk/issues
documentation: https://github.com/BurhanRabbani/acs_flutter_sdk#readme
```

---

### Step 4: Commit and Push the Updated pubspec.yaml

```bash
# Add the updated pubspec.yaml
git add pubspec.yaml

# Commit the change
git commit -m "Update repository URLs in pubspec.yaml for pub.dev publication"

# Push to GitHub
git push
```

---

### Step 5: Verify Repository is Public and Accessible

1. Visit: https://github.com/BurhanRabbani/acs_flutter_sdk
2. Verify the repository is public (should see a "Public" badge)
3. Verify all files are present
4. Verify README.md displays correctly

---

### Step 6: Re-run Pana Analysis

```bash
# Run pana analysis
flutter pub publish --dry-run

# Or run pana directly for detailed scoring
dart pub global activate pana
pana --no-warning .
```

**Expected Output:**
```
Package score: 160/160 points
✅ Follow Dart file conventions (20/20)
✅ Provide documentation (10/10)
✅ Platform support (20/20)
✅ Pass static analysis (50/50)
✅ Support up-to-date dependencies (40/40)
✅ Support repository URLs (10/10)  ← Fixed!
✅ Homepage/Documentation URLs reachable (10/10)  ← Fixed!
```

---

## Verification Checklist

Before publishing to pub.dev, verify:

- ✅ GitHub repository created and public
- ✅ All code pushed to GitHub
- ✅ Repository URLs updated in pubspec.yaml
- ✅ All URLs are accessible (no 404 errors)
- ✅ README.md displays correctly on GitHub
- ✅ LICENSE file is present
- ✅ Pana score is 160/160
- ✅ `flutter pub publish --dry-run` passes with 0 warnings
- ✅ All 68 tests pass

---

## Troubleshooting

### Issue: "remote: Repository not found"
**Solution:** Make sure you created the repository on GitHub first.

### Issue: "Authentication failed"
**Solution:** 
- Use GitHub Personal Access Token for HTTPS
- Or set up SSH keys: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

### Issue: "Pana still shows 140/160"
**Solution:**
1. Make sure you pushed the updated pubspec.yaml to GitHub
2. Wait a few minutes for GitHub to index the repository
3. Clear pana cache: `rm -rf ~/.pub-cache/hosted/pub.dev/acs_flutter_sdk*`
4. Run pana again

### Issue: "URLs still unreachable"
**Solution:**
1. Verify repository is public (not private)
2. Check URLs in browser manually
3. Make sure repository name matches exactly: `acs_flutter_sdk`

---

## Next Steps After 160/160 Score

Once you achieve the perfect score:

1. **Review the package one final time**
2. **Test on physical devices** (optional but recommended)
3. **Publish to pub.dev:**
   ```bash
   flutter pub publish
   ```
4. **Monitor package health** on pub.dev
5. **Respond to issues** on GitHub

---

## Summary

**What you need to do:**

1. ✅ Create GitHub repository: `acs_flutter_sdk`
2. ✅ Run git commands to initialize and push
3. ✅ Verify pubspec.yaml is updated (already done automatically)
4. ✅ Push updated pubspec.yaml
5. ✅ Run pana analysis to verify 160/160

**Estimated time:** 5-10 minutes

**Result:** Perfect 160/160 pana score and ready for pub.dev publication! 🎉

---

**Your GitHub Repository URL:** https://github.com/BurhanRabbani/acs_flutter_sdk

**Note:** If your GitHub username is different from "BurhanRabbani", update the URLs accordingly in pubspec.yaml.

