/**
 * Email Templates for TestFlight Welcome Emails
 */

/**
 * Generate HTML version of welcome email
 */
export function getWelcomeEmailHTML(firstName: string, betaCode: string): string {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Welcome to QuillStack Beta</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      line-height: 1.6;
      color: #2D3A2E;
      max-width: 600px;
      margin: 0 auto;
      padding: 0;
      background-color: #FAF7F2;
    }
    .header {
      background: linear-gradient(180deg, #143d23 0%, #1e4d2f 100%);
      padding: 40px 20px;
      text-align: center;
      border-radius: 0;
    }
    .logo {
      width: 120px;
      height: 120px;
      margin: 0 auto 20px;
    }
    h1 {
      color: #e8f0e8;
      margin: 0 0 8px;
      font-size: 32px;
      font-weight: 700;
      font-family: Georgia, 'Times New Roman', serif;
      letter-spacing: 0.5px;
    }
    .subtitle {
      color: #d4e0d4;
      font-size: 16px;
      margin: 0;
      font-weight: 400;
    }
    .content {
      background: white;
      padding: 40px 30px;
      margin: 0;
    }
    .intro {
      font-size: 16px;
      margin-bottom: 30px;
      line-height: 1.7;
    }
    .intro-link {
      display: inline-block;
      color: #1e4d2f;
      font-weight: 600;
      text-decoration: none;
      border-bottom: 2px solid #1e4d2f;
      margin-top: 10px;
    }
    .intro-link:hover {
      background: #e8f0e8;
    }
    h2 {
      color: #1e4d2f;
      font-size: 22px;
      margin: 35px 0 20px;
      font-weight: 700;
      font-family: Georgia, 'Times New Roman', serif;
    }
    .feature {
      padding: 20px 0;
      border-bottom: 1px solid #E8E4DC;
    }
    .feature:last-child {
      border-bottom: none;
      padding-bottom: 0;
    }
    .feature-header {
      display: flex;
      align-items: flex-start;
      gap: 14px;
      margin-bottom: 8px;
    }
    .feature-icon {
      width: 32px;
      height: 32px;
      flex-shrink: 0;
      margin-top: 0px;
    }
    .feature-icon svg {
      width: 100%;
      height: 100%;
      color: #1e4d2f;
    }
    .feature-title {
      font-weight: 600;
      color: #1e4d2f;
      font-size: 17px;
      margin: 0 0 4px;
    }
    .feature-description {
      margin: 0 0 0 42px;
      color: #4a6b4f;
      line-height: 1.6;
    }
    .feature-description + .feature-description {
      margin-top: 10px;
    }
    code {
      background: #F0EDE7;
      padding: 3px 8px;
      border-radius: 4px;
      font-family: 'SF Mono', Monaco, Consolas, monospace;
      font-size: 14px;
      color: #1e4d2f;
      font-weight: 600;
    }
    .steps {
      margin: 20px 0 0 42px;
      padding-left: 0;
      list-style: none;
      counter-reset: step-counter;
    }
    .steps li {
      counter-increment: step-counter;
      margin-bottom: 12px;
      padding-left: 35px;
      position: relative;
      color: #4a6b4f;
      line-height: 1.6;
    }
    .steps li::before {
      content: counter(step-counter);
      position: absolute;
      left: 0;
      top: 0;
      background: #1e4d2f;
      color: white;
      width: 24px;
      height: 24px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 13px;
      font-weight: 600;
    }
    .cta-container {
      text-align: center;
      margin: 35px 0 25px;
    }
    .cta-button {
      display: inline-block;
      background: #1e4d2f;
      color: white;
      padding: 16px 36px;
      border-radius: 8px;
      text-decoration: none;
      font-weight: 600;
      font-size: 16px;
      box-shadow: 0 2px 8px rgba(30, 77, 47, 0.2);
    }
    .cta-button:hover {
      background: #143d23;
    }
    .closing {
      margin-top: 30px;
      color: #4a6b4f;
      font-size: 15px;
    }
    .signature {
      margin-top: 25px;
      font-weight: 500;
      color: #1e4d2f;
    }
    .footer {
      text-align: center;
      padding: 30px 20px;
      color: #7A8A7C;
      font-size: 13px;
      line-height: 1.6;
      background: #FAF7F2;
    }
    .footer a {
      color: #1e4d2f;
      text-decoration: none;
      font-weight: 500;
    }
    .footer a:hover {
      text-decoration: underline;
    }
    .beta-code-section {
      background: linear-gradient(135deg, #1e4d2f 0%, #143d23 100%);
      padding: 30px;
      border-radius: 12px;
      margin: 30px 0;
      text-align: center;
      box-shadow: 0 4px 12px rgba(30, 77, 47, 0.25);
    }
    .beta-code-label {
      color: #d4e0d4;
      font-size: 14px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 12px;
    }
    .beta-code {
      background: white;
      color: #1e4d2f;
      font-family: 'SF Mono', Monaco, Consolas, monospace;
      font-size: 28px;
      font-weight: 700;
      padding: 16px 24px;
      border-radius: 8px;
      display: inline-block;
      letter-spacing: 2px;
      margin: 8px 0;
      border: 3px solid #e8f0e8;
    }
    .beta-code-instructions {
      color: #e8f0e8;
      font-size: 14px;
      margin-top: 12px;
      line-height: 1.6;
    }
  </style>
</head>
<body>
  <div class="header">
    <img src="https://quillstack.io/logo.png" alt="QuillStack" class="logo">
    <h1>Welcome to QuillStack Beta</h1>
    <p class="subtitle">Transform Handwriting Into Action</p>
  </div>

  <div class="content">
    <div class="intro">
      <p>Hey ${firstName},</p>

      <p>Welcome to QuillStack! You're among the first to experience handwriting capture that actually understands what you write.</p>

      <p>Most OCR apps just convert text. QuillStack goes further—it reads your handwritten notes, recognizes what type of note it is, and routes it to the right place with purpose-built features.</p>

      <a href="https://quillstack.io" class="intro-link">Visit quillstack.io to learn more →</a>
    </div>

    <div class="beta-code-section">
      <div class="beta-code-label">Your Beta Access Code</div>
      <div class="beta-code">${betaCode}</div>
      <div class="beta-code-instructions">
        Enter this code in Settings → AI Enhancement to unlock 500 free credits for AI-powered text enhancement.
        <br><strong>No credit card required.</strong>
      </div>
    </div>

    <h2>What Makes QuillStack Different</h2>

    <div class="feature">
      <div class="feature-header">
        <div class="feature-icon">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/>
            <circle cx="12" cy="13" r="3"/>
          </svg>
        </div>
        <h3 class="feature-title">Intelligent OCR</h3>
      </div>
      <p class="feature-description">
        Advanced recognition powered by Apple Vision with per-word confidence scores. Low-confidence words are highlighted so you can correct what matters. The system learns from your corrections.
      </p>
    </div>

    <div class="feature">
      <div class="feature-header">
        <div class="feature-icon">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="4" y1="9" x2="20" y2="9"/>
            <line x1="4" y1="15" x2="20" y2="15"/>
            <line x1="10" y1="3" x2="8" y2="21"/>
            <line x1="16" y1="3" x2="14" y2="21"/>
          </svg>
        </div>
        <h3 class="feature-title">Smart Classification</h3>
      </div>
      <p class="feature-description">
        Write hashtag triggers to auto-route notes to specialized views:
      </p>
      <p class="feature-description">
        <code>#todo#</code> Syncs tasks to Apple Reminders with checkboxes
      </p>
      <p class="feature-description">
        <code>#meeting#</code> Converts to calendar events with parsed attendees
      </p>
      <p class="feature-description">
        <code>#recipe#</code> Formatted recipe cards with ingredients and instructions
      </p>
      <p class="feature-description">
        <code>#expense#</code> Photo a receipt to auto-parse amounts and categories
      </p>
      <p class="feature-description">
        <code>#issue#</code> Creates GitHub Issues directly from your handwritten notes
      </p>
      <p class="feature-description">
        <code>#email#</code> Drafts emails with recipient detection
      </p>
      <p class="feature-description">
        <code>#shopping#</code> Checkable grocery lists exported to Apple Reminders
      </p>
      <p class="feature-description">
        <code>#contact#</code> Creates phone contacts from handwriting or business cards
      </p>
      <p class="feature-description" style="margin-top: 15px; font-style: italic;">
        Plus Event, Reminder, ClaudePrompt, and General note types—12 in total, each with custom features.
      </p>
    </div>

    <div class="feature">
      <div class="feature-header">
        <div class="feature-icon">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/>
            <path d="M5 3v4"/>
            <path d="M19 17v4"/>
            <path d="M3 5h4"/>
            <path d="M17 19h4"/>
          </svg>
        </div>
        <h3 class="feature-title">AI Enhancement (Optional)</h3>
      </div>
      <p class="feature-description">
        Clean up OCR errors with Claude API integration. Your API key, your control—data stays on-device with optional iCloud sync.
      </p>
    </div>

    <div class="feature">
      <div class="feature-header">
        <div class="feature-icon">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
            <polyline points="15 3 21 3 21 9"/>
            <line x1="10" y1="14" x2="21" y2="3"/>
          </svg>
        </div>
        <h3 class="feature-title">Export Everywhere</h3>
      </div>
      <p class="feature-description">
        Send notes to Apple Notes, Notion, Obsidian, or PDF with type-specific formatting preserved.
      </p>
    </div>

    <h2>Get Started</h2>
    <ol class="steps">
      <li>Open QuillStack from TestFlight</li>
      <li>Go to Settings → AI Enhancement and enter your beta code: <code>${betaCode}</code></li>
      <li>Point your camera at any handwritten note</li>
      <li>Add hashtag triggers to unlock smart features</li>
      <li>Export or sync to your favorite tools</li>
    </ol>

    <div class="cta-container">
      <a href="https://quillstack.io" class="cta-button">Visit quillstack.io</a>
    </div>

    <h2>We Need Your Feedback</h2>
    <div class="closing">
      <p>As a beta tester, you're shaping QuillStack's future. Found a bug? Have a feature idea? Reply to this email—we read everything.</p>
    </div>

    <div class="signature">
      <p>Happy capturing,<br>
      <strong>The QuillStack Team</strong></p>
    </div>
  </div>

  <div class="footer">
    <p>You're receiving this because you joined the QuillStack TestFlight beta.</p>
    <p><a href="https://quillstack.io">quillstack.io</a> • <a href="mailto:support@quillstack.io">support@quillstack.io</a></p>
  </div>
</body>
</html>
  `.trim();
}

/**
 * Generate plain text version of welcome email
 */
export function getWelcomeEmailText(firstName: string, betaCode: string): string {
  return `
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  WELCOME TO QUILLSTACK BETA
  Transform Handwriting Into Action
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Hey ${firstName},

Welcome to QuillStack! You're among the first to experience handwriting capture that actually understands what you write.

Most OCR apps just convert text. QuillStack goes further—it reads your handwritten notes, recognizes what type of note it is, and routes it to the right place with purpose-built features.

Visit quillstack.io to learn more →
https://quillstack.io

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔑 YOUR BETA ACCESS CODE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${betaCode}

Enter this code in Settings → AI Enhancement to unlock 500 free credits for AI-powered text enhancement. No credit card required.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHAT MAKES QUILLSTACK DIFFERENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📷 INTELLIGENT OCR
Advanced recognition powered by Apple Vision with per-word confidence scores. Low-confidence words are highlighted so you can correct what matters. The system learns from your corrections.

# SMART CLASSIFICATION
Write hashtag triggers to auto-route notes to specialized views:

#todo# - Syncs tasks to Apple Reminders with checkboxes
#meeting# - Converts to calendar events with parsed attendees
#recipe# - Formatted recipe cards with ingredients and instructions
#expense# - Photo a receipt to auto-parse amounts and categories
#issue# - Creates GitHub Issues directly from your handwritten notes
#email# - Drafts emails with recipient detection
#shopping# - Checkable grocery lists exported to Apple Reminders
#contact# - Creates phone contacts from handwriting or business cards

Plus Event, Reminder, ClaudePrompt, and General note types—12 in total, each with custom features.

✨ AI ENHANCEMENT (OPTIONAL)
Clean up OCR errors with Claude API integration. Your API key, your control—data stays on-device with optional iCloud sync.

↗ EXPORT EVERYWHERE
Send notes to Apple Notes, Notion, Obsidian, or PDF with type-specific formatting preserved.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GET STARTED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Open QuillStack from TestFlight
2. Go to Settings → AI Enhancement and enter your beta code: ${betaCode}
3. Point your camera at any handwritten note
4. Add hashtag triggers to unlock smart features
5. Export or sync to your favorite tools

Visit quillstack.io
https://quillstack.io

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WE NEED YOUR FEEDBACK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

As a beta tester, you're shaping QuillStack's future. Found a bug? Have a feature idea? Reply to this email—we read everything.

Happy capturing,
The QuillStack Team

---
You're receiving this because you joined the QuillStack TestFlight beta.
https://quillstack.io • support@quillstack.io
  `.trim();
}
