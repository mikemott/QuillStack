# Cursor Integration Guide

This guide explains how to integrate Cursor into your existing QuillStack development workflow alongside Claude, Linear, GitHub, Qodo, Sentry, and Cloudflare Workers.

## Overview: Where Cursor Fits

Cursor complements your existing tools rather than replacing them:

| Tool | Primary Use | Cursor's Role |
|------|-------------|---------------|
| **Linear** | Project management, issue tracking | Cursor helps implement Linear issues |
| **GitHub** | Version control, PRs | Cursor commits/pushes, you create PRs |
| **PR-Agent** | Automated code review | Cursor for implementation, PR-Agent for review |
| **Claude (API)** | LLM features in app | Cursor for development, Claude for runtime |
| **Sentry** | Error & performance tracking | Cursor helps fix errors and optimize performance issues from Sentry |
| **Cloudflare Workers** | Backend services | Cursor helps develop/maintain workers |

## Recommended Workflow with Cursor

### 1. Planning Phase (Keep Using Linear)

**Before coding:**
- Create Linear issue (QUI-XX) as usual
- Discuss approach in Linear comments or with Claude
- Use Cursor's Chat to explore implementation options

**Cursor tip:** Use `@CLAUDE.md` or `@FEATURE_PLAN.md` to give Cursor context about your architecture.

### 2. Development Phase (Cursor + Your Tools)

**Option A: Cursor Composer (Recommended for Features)**
```bash
# 1. Create branch (keep your naming convention)
git checkout -b qui-XX-short-description

# 2. Use Cursor Composer for multi-file changes
# - Open Cursor Composer (Cmd+I)
# - Reference Linear issue: "Implement QUI-XX: Feature description"
# - Reference relevant files: @Services/TextClassifier.swift
# - Let Cursor implement the feature

# 3. Review changes in Cursor's diff view
# 4. Commit with clear message
git commit -m "Implement QUI-XX: Feature description"
```

**Option B: Cursor Chat (For Iterative Development)**
- Use Chat (Cmd+L) for:
  - Quick questions about codebase
  - Small refactors
  - Debugging help
  - Code explanations

**Option C: Inline Edits (For Small Changes)**
- Use Cmd+K for quick inline edits
- Great for fixing typos, small refactors, adding comments

### 3. Testing & Review Phase (Keep Your Automation)

**After implementation:**
```bash
# 1. Test locally
# 2. Commit and push
git push origin qui-XX-short-description

# 3. Create PR (keep your existing workflow)
gh pr create --title "QUI-XX: Feature description" --body "Closes QUI-XX

[Description of changes]

Implements [Linear issue link]"

# 4. Your automation handles the rest:
#    - PR-Agent reviews with Claude Sonnet 4.5
#    - Linear sync updates issue to "In Review"
#    - PR link added to Linear issue
```

## Cursor Features for Your Stack

### 1. Codebase Understanding

**Use Cursor's semantic search:**
- Ask: "How does OCR processing work?"
- Ask: "Where are note types classified?"
- Ask: "How does Linear sync work in GitHub Actions?"

**Cursor will:**
- Search your codebase semantically
- Show relevant files
- Explain relationships

### 2. Multi-File Refactoring

**Example: Adding a new note type**
```
1. Use Composer: "Add a new note type #invoice# following the plugin pattern"
2. Cursor will:
   - Create plugin in Services/Plugins/BuiltIn/
   - Update TextClassifier.swift
   - Create detail view in Views/
   - Update NoteType enum
3. Review all changes in diff view
4. Commit as single unit
```

### 3. Cloudflare Workers Development

**For your Workers (api-proxy-worker, testflight-welcome-worker):**
- Use Cursor Chat to understand worker logic
- Use Composer for adding features
- Reference `wrangler.toml` for configuration context

**Example:**
```
@api-proxy-worker/src/index.ts "Add rate limiting per beta code"
```

### 4. Debugging with Sentry Context

**When Sentry reports an error:**
1. Open Sentry issue
2. Copy error details
3. In Cursor Chat: "Fix this Sentry error: [paste error]"
4. Cursor will:
   - Find relevant code
   - Understand error context
   - Suggest fix
   - Add better error handling

**When Sentry reports performance issues:**
1. Share Sentry performance issue URL or data
2. In Cursor Chat: "Review this Sentry performance issue: [URL/data]"
3. Cursor will:
   - Analyze performance bottlenecks
   - Identify slow operations
   - Suggest optimizations
   - Help implement fixes

**See:** `CURSOR-SENTRY-INTEGRATION.md` for complete Sentry + Cursor workflow

### 5. GitHub Integration

**Cursor can:**
- Read GitHub issues (via API or you paste them)
- Understand PR context
- Help write PR descriptions
- Review code before you push

**Tip:** Use `@.github/workflows/` to show Cursor your CI/CD setup.

## Best Practices

### 1. Maintain Your Workflow

**Keep using:**
- ✅ Linear for planning and tracking
- ✅ GitHub PRs for code review
- ✅ PR-Agent for automated reviews
- ✅ Your branch naming: `qui-XX-description`

**Cursor helps with:**
- ✅ Implementation speed
- ✅ Code understanding
- ✅ Refactoring
- ✅ Bug fixes

### 2. Use Cursor Context Files

Create a `.cursorrules` file (optional) to guide Cursor:

```markdown
# QuillStack Development Rules

- Follow MVVM architecture
- Use @MainActor for ViewModels
- Use @Observable for state management
- Follow note type plugin pattern in Services/Plugins/BuiltIn/
- Branch names: qui-XX-short-description
- PR descriptions should include "Closes QUI-XX"
- Use SentrySDK.capture() for error tracking
- iOS target: 26.2+, Swift 6.0
```

### 3. Reference Documentation

**When using Cursor, reference:**
- `@CLAUDE.md` - Development workflow
- `@FEATURE_PLAN.md` - Feature specifications
- `@TODO-architecture-refactor.md` - Architecture notes
- `@DEPLOYMENT-STATUS.md` - Deployment info

**Example:**
```
@CLAUDE.md @Services/TextClassifier.swift "Add support for #invoice# note type"
```

### 4. Code Review Workflow

**Recommended flow:**
1. **Cursor Composer** → Implement feature
2. **Cursor Chat** → "Review this code for issues"
3. **Local testing** → Test your changes
4. **Create PR** → Use `gh pr create`
5. **PR-Agent** → Automated review (keeps working)
6. **Address feedback** → Use Cursor Chat to help fix issues
7. **Merge** → Linear auto-closes issue

### 5. Integration with Qodo

**If Qodo is for task management:**
- Use Cursor to implement Qodo-related features
- Reference Qodo API docs in Cursor Chat
- Use Composer for Qodo integrations

## Common Workflows

### Adding a New Feature

```bash
# 1. Linear: Create QUI-XX issue
# 2. Cursor: Use Composer with Linear context
#    "Implement QUI-XX: [feature]. See Linear issue for details"
# 3. Review in Cursor diff view
# 4. Test locally
# 5. Commit: git commit -m "QUI-XX: Feature description"
# 6. Push and create PR with "Closes QUI-XX"
# 7. PR-Agent reviews, Linear syncs
```

### Fixing a Bug

```bash
# 1. Sentry/Linear: Identify bug (QUI-XX)
# 2. Cursor Chat: "Fix this bug: [description]"
# 3. Cursor finds relevant code
# 4. Review fix in diff view
# 5. Test fix
# 6. Commit: git commit -m "QUI-XX: Fix [bug description]"
# 7. Push and create PR
```

### Refactoring

```bash
# 1. Cursor Composer: "Refactor [component] to [new pattern]"
# 2. Review all changes
# 3. Test thoroughly
# 4. Commit with clear message
# 5. Create PR if significant
```

### Cloudflare Worker Updates

```bash
# 1. Navigate to worker directory
cd api-proxy-worker

# 2. Cursor Chat: "Add [feature] to this worker"
# 3. Review changes
# 4. Test locally: npx wrangler dev
# 5. Deploy: npx wrangler deploy
```

## Cursor vs. Your Existing Tools

### Cursor vs. Claude (in Cursor Chat)

**Cursor Chat:**
- ✅ Has full codebase context
- ✅ Can make edits directly
- ✅ Understands your project structure
- ✅ Faster for code-specific questions

**Claude (via API in your app):**
- ✅ Runtime LLM features
- ✅ User-facing AI features
- ✅ OCR enhancement
- ✅ Different use case

**Use both:** Cursor for development, Claude API for app features.

### Cursor vs. PR-Agent

**Cursor:**
- ✅ Implementation assistance
- ✅ Code generation
- ✅ Refactoring help
- ✅ Development-time tool

**PR-Agent:**
- ✅ Automated PR reviews
- ✅ Code quality checks
- ✅ Consistency validation
- ✅ Post-implementation review

**Use both:** Cursor to build, PR-Agent to review.

## Tips for Maximum Efficiency

1. **Start with Context**
   - Always reference relevant files: `@file.swift`
   - Reference docs: `@CLAUDE.md`
   - Mention Linear issues: "QUI-XX"

2. **Use Composer for Multi-File Changes**
   - Better than Chat for features touching multiple files
   - Shows unified diff view
   - Easier to review

3. **Use Chat for Questions**
   - "How does X work?"
   - "Why is this code structured this way?"
   - "What's the best way to implement Y?"

4. **Keep Your Workflow**
   - Don't skip Linear issues
   - Don't skip PRs for non-trivial changes
   - Don't skip PR-Agent reviews

5. **Leverage Cursor's Understanding**
   - Ask about architecture decisions
   - Understand code relationships
   - Get suggestions for improvements

## Troubleshooting

### Cursor Not Understanding Context

**Solution:**
- Reference specific files: `@Services/TextClassifier.swift`
- Reference documentation: `@CLAUDE.md`
- Provide more context in your prompt

### Conflicts with PR-Agent

**Solution:**
- Cursor helps you write code
- PR-Agent reviews it
- They complement each other
- Address PR-Agent feedback using Cursor Chat

### Maintaining Code Quality

**Solution:**
- Use Cursor's suggestions as starting points
- Always review generated code
- Run tests before committing
- Let PR-Agent catch issues you miss

## Summary

**Cursor enhances your workflow by:**
- ✅ Speeding up implementation
- ✅ Helping understand codebase
- ✅ Assisting with refactoring
- ✅ Providing code suggestions

**Your existing tools still handle:**
- ✅ Project management (Linear)
- ✅ Code review (PR-Agent)
- ✅ Error tracking (Sentry)
- ✅ Backend services (Cloudflare Workers)

**Best approach:**
1. Plan in Linear
2. Implement with Cursor
3. Review with PR-Agent
4. Deploy and monitor with Sentry

Cursor is a powerful development assistant that fits seamlessly into your existing, well-structured workflow.

