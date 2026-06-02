// ============================================================================
// Supabase Edge Function: notify-activation-request
// ============================================================================
// Sends email notifications to developers when customers request activation codes
// Supports multiple notification channels: Email, Webhook (Slack/Discord)
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const SENDGRID_API_KEY = Deno.env.get('SENDGRID_API_KEY')
const SMTP_HOST = Deno.env.get('SMTP_HOST')
const SMTP_PORT = Deno.env.get('SMTP_PORT') || '587'
const SMTP_USER = Deno.env.get('SMTP_USER')
const SMTP_PASS = Deno.env.get('SMTP_PASS')

interface ActivationRequest {
  request_id: string
  business_name: string
  package_name: string
  package_price: string
  request_type: string
  contact_email: string
  contact_phone: string
  additional_notes?: string
  requested_at: string
  notification_email: string
  webhook_url?: string
  email_enabled: boolean
  webhook_enabled: boolean
}

serve(async (req: Request) => {
  try {
    const request: ActivationRequest = await req.json()
    const results = []

    console.log('📬 New activation request received:', {
      business: request.business_name,
      package: request.package_name,
      email_enabled: request.email_enabled,
      webhook_enabled: request.webhook_enabled,
    })

    // Send email notification
    if (request.email_enabled && request.notification_email) {
      const emailResult = await sendEmailNotification(request)
      results.push(emailResult)
    }

    // Send webhook notification (Slack, Discord, etc.)
    if (request.webhook_enabled && request.webhook_url) {
      const webhookResult = await sendWebhookNotification(request)
      results.push(webhookResult)
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Notifications sent successfully',
        results,
      }),
      { 
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('❌ Error in notify-activation-request:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: errorMessage 
      }),
      { 
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

// ============================================================================
// Email Notification Functions
// ============================================================================

async function sendEmailNotification(request: ActivationRequest) {
  // Try Resend first (recommended for simplicity)
  if (RESEND_API_KEY) {
    return await sendViaResend(request)
  }
  // Fallback to SendGrid
  else if (SENDGRID_API_KEY) {
    return await sendViaSendGrid(request)
  }
  // Fallback to generic SMTP
  else if (SMTP_HOST && SMTP_USER && SMTP_PASS) {
    return await sendViaSMTP(request)
  }
  else {
    console.warn('⚠️ No email service configured')
    return { 
      type: 'email', 
      success: false, 
      message: 'No email service configured' 
    }
  }
}

// Send via Resend.com (Recommended - easiest setup)
async function sendViaResend(request: ActivationRequest) {
  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: 'Smart Monitoring System <noreply@yourdomain.com>',
        to: request.notification_email,
        subject: `🔔 New Activation Request: ${request.business_name}`,
        html: buildEmailHTML(request),
      }),
    })

    const data = await response.json()
    
    if (response.ok) {
      console.log('✅ Email sent via Resend:', data.id)
      return { type: 'email', success: true, provider: 'resend', id: data.id }
    } else {
      console.error('❌ Resend error:', data)
      return { type: 'email', success: false, provider: 'resend', error: data }
    }
  } catch (error) {
    console.error('❌ Resend exception:', error)
    const errorMessage = error instanceof Error ? error.message : String(error)
    return { type: 'email', success: false, provider: 'resend', error: errorMessage }
  }
}

// Send via SendGrid
async function sendViaSendGrid(request: ActivationRequest) {
  try {
    const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
      },
      body: JSON.stringify({
        personalizations: [{
          to: [{ email: request.notification_email }],
        }],
        from: { 
          email: 'noreply@yourdomain.com',
          name: 'Smart Monitoring System'
        },
        subject: `🔔 New Activation Request: ${request.business_name}`,
        content: [{
          type: 'text/html',
          value: buildEmailHTML(request),
        }],
      }),
    })

    if (response.ok) {
      console.log('✅ Email sent via SendGrid')
      return { type: 'email', success: true, provider: 'sendgrid' }
    } else {
      const error = await response.text()
      console.error('❌ SendGrid error:', error)
      return { type: 'email', success: false, provider: 'sendgrid', error }
    }
  } catch (error) {
    console.error('❌ SendGrid exception:', error)
    const errorMessage = error instanceof Error ? error.message : String(error)
    return { type: 'email', success: false, provider: 'sendgrid', error: errorMessage }
  }
}

// Send via generic SMTP (fallback)
async function sendViaSMTP(request: ActivationRequest) {
  // Note: Deno's SMTP support is limited. Consider using a service instead.
  console.log('⚠️ SMTP sending not fully implemented. Use Resend or SendGrid instead.')
  return { 
    type: 'email', 
    success: false, 
    provider: 'smtp',
    message: 'SMTP not implemented. Use Resend or SendGrid.' 
  }
}

// Build HTML email content
function buildEmailHTML(request: ActivationRequest): string {
  const formattedDate = new Date(request.requested_at).toLocaleString()
  
  return `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #fff; padding: 30px; border: 1px solid #ddd; }
    .info-row { margin: 15px 0; padding: 12px; background: #f8f9fa; border-left: 4px solid #667eea; }
    .label { font-weight: bold; color: #667eea; display: inline-block; width: 140px; }
    .value { color: #333; }
    .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white !important; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🔔 New Activation Request</h1>
      <p>A customer has requested an activation code</p>
    </div>
    
    <div class="content">
      <h2>Customer Information</h2>
      <div class="info-row">
        <span class="label">Business Name:</span>
        <span class="value">${request.business_name}</span>
      </div>
      <div class="info-row">
        <span class="label">Contact Email:</span>
        <span class="value">${request.contact_email}</span>
      </div>
      <div class="info-row">
        <span class="label">Contact Phone:</span>
        <span class="value">${request.contact_phone}</span>
      </div>
      
      <h2>Package Details</h2>
      <div class="info-row">
        <span class="label">Package:</span>
        <span class="value">${request.package_name}</span>
      </div>
      <div class="info-row">
        <span class="label">Price:</span>
        <span class="value">${request.package_price}</span>
      </div>
      <div class="info-row">
        <span class="label">Request Type:</span>
        <span class="value">${request.request_type.toUpperCase()}</span>
      </div>
      <div class="info-row">
        <span class="label">Requested At:</span>
        <span class="value">${formattedDate}</span>
      </div>
      
      ${request.additional_notes ? `
      <h2>Additional Notes</h2>
      <div class="info-row">
        <span class="value">${request.additional_notes}</span>
      </div>
      ` : ''}
      
      <div style="text-align: center; margin-top: 30px;">
        <a href="${Deno.env.get('APP_URL')}/developer-dashboard" class="button">
          View in Dashboard
        </a>
      </div>
    </div>
    
    <div class="footer">
      <p>Smart Monitoring System - Developer Notification</p>
      <p>Request ID: ${request.request_id}</p>
    </div>
  </div>
</body>
</html>
  `
}

// ============================================================================
// Webhook Notification (Slack, Discord, etc.)
// ============================================================================

async function sendWebhookNotification(request: ActivationRequest) {
  try {
    const webhookUrl = request.webhook_url!
    
    // Determine webhook type by URL
    const isSlack = webhookUrl.includes('slack.com')
    const isDiscord = webhookUrl.includes('discord.com')
    
    let payload: any
    
    if (isSlack) {
      payload = buildSlackPayload(request)
    } else if (isDiscord) {
      payload = buildDiscordPayload(request)
    } else {
      // Generic webhook format
      payload = {
        event: 'activation_request',
        data: request,
      }
    }
    
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })
    
    if (response.ok) {
      console.log('✅ Webhook sent successfully')
      return { type: 'webhook', success: true }
    } else {
      const error = await response.text()
      console.error('❌ Webhook error:', error)
      return { type: 'webhook', success: false, error }
    }
  } catch (error) {
    console.error('❌ Webhook exception:', error)
    const errorMessage = error instanceof Error ? error.message : String(error)
    return { type: 'webhook', success: false, error: errorMessage }
  }
}

function buildSlackPayload(request: ActivationRequest) {
  return {
    text: `🔔 New Activation Request from ${request.business_name}`,
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: '🔔 New Activation Request',
        },
      },
      {
        type: 'section',
        fields: [
          {
            type: 'mrkdwn',
            text: `*Business:*\n${request.business_name}`,
          },
          {
            type: 'mrkdwn',
            text: `*Package:*\n${request.package_name}`,
          },
          {
            type: 'mrkdwn',
            text: `*Email:*\n${request.contact_email}`,
          },
          {
            type: 'mrkdwn',
            text: `*Phone:*\n${request.contact_phone}`,
          },
        ],
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Type:* ${request.request_type.toUpperCase()} | *Price:* ${request.package_price}`,
        },
      },
    ],
  }
}

function buildDiscordPayload(request: ActivationRequest) {
  return {
    content: '🔔 **New Activation Request**',
    embeds: [
      {
        title: request.business_name,
        color: 0x667eea, // Purple color
        fields: [
          {
            name: '📦 Package',
            value: `${request.package_name} (${request.package_price})`,
            inline: true,
          },
          {
            name: '📋 Type',
            value: request.request_type.toUpperCase(),
            inline: true,
          },
          {
            name: '📧 Email',
            value: request.contact_email,
            inline: true,
          },
          {
            name: '📱 Phone',
            value: request.contact_phone,
            inline: true,
          },
        ],
        timestamp: request.requested_at,
      },
    ],
  }
}

/* To disable this function, uncomment this:
Deno.serve(() => new Response("ok"))
*/
