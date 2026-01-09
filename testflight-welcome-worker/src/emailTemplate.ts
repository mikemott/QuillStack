/**
 * Email Templates for TestFlight Welcome Emails
 */

/**
 * Generate HTML version of welcome email
 */
export function getWelcomeEmailHTML(firstName: string): string {
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

      <p>Most note apps make you organize everything manually. QuillStack reads your handwriting and figures out what it is automatically.</p>
    </div>

    <h2>Try This Right Now</h2>
    <div class="feature">
      <p class="feature-description">
        Write a quick todo list on paper. Open QuillStack, snap a photo. The app recognizes it's a todo list and syncs each item to Apple Reminders automatically. No hashtags, no manual categorizing—just write and capture.
      </p>
    </div>

    <h2>Getting Started</h2>
    <ol class="steps">
      <li>Open QuillStack from TestFlight</li>
      <li>Go to Settings and add your Anthropic API key from <a href="https://console.anthropic.com" style="color: #1e4d2f; font-weight: 600;">console.anthropic.com</a></li>
      <li>Point your camera at any handwritten note</li>
      <li>Watch it automatically organize itself</li>
    </ol>

    <h2>What Makes This Different</h2>
    <div class="feature">
      <p class="feature-description">
        <strong>No manual organizing.</strong> QuillStack uses AI to detect whether you wrote a todo list, meeting notes, a recipe, an email draft, or one of 8 other note types. Each type gets custom formatting and actions.
      </p>
      <p class="feature-description" style="margin-top: 15px;">
        <strong>Your privacy matters.</strong> Everything stays on your device. The optional Claude API enhancement uses your own API key—you're in control, and nothing is stored on our servers.
      </p>
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
export function getWelcomeEmailText(firstName: string): string {
  return `
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  WELCOME TO QUILLSTACK BETA
  Transform Handwriting Into Action
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Hey ${firstName},

Most note apps make you organize everything manually. QuillStack reads your handwriting and figures out what it is automatically.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TRY THIS RIGHT NOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Write a quick todo list on paper. Open QuillStack, snap a photo. The app recognizes it's a todo list and syncs each item to Apple Reminders automatically. No hashtags, no manual categorizing—just write and capture.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GETTING STARTED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Open QuillStack from TestFlight
2. Go to Settings and add your Anthropic API key from console.anthropic.com
3. Point your camera at any handwritten note
4. Watch it automatically organize itself

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHAT MAKES THIS DIFFERENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

NO MANUAL ORGANIZING
QuillStack uses AI to detect whether you wrote a todo list, meeting notes, a recipe, an email draft, or one of 8 other note types. Each type gets custom formatting and actions.

YOUR PRIVACY MATTERS
Everything stays on your device. The optional Claude API enhancement uses your own API key—you're in control, and nothing is stored on our servers.

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
