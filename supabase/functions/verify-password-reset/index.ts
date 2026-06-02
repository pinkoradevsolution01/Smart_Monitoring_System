// ============================================================================
// Supabase Edge Function: verify-password-reset
// ============================================================================
// Verifies reset token and updates owner password
// Called from: password_reset_service.dart → verifyAndResetPassword()
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// In-memory storage shared with send-password-reset function
// In production, use Supabase database
const resetTokens = new Map<string, { email: string; expires: number }>()

interface VerifyResetPayload {
  token: string
  newPassword: string
}

interface SuccessResponse {
  success: true
  email: string
  message: string
}

interface ErrorResponse {
  success: false
  error: string
  message?: string
}

type ApiResponse = SuccessResponse | ErrorResponse

serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload: VerifyResetPayload = await req.json()
    const { token, newPassword } = payload

    if (!token || !newPassword) {
      const errorResponse: ErrorResponse = {
        success: false,
        error: 'Missing required fields: token and newPassword'
      }
      return new Response(
        JSON.stringify(errorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate password strength
    if (newPassword.length < 6) {
      const errorResponse: ErrorResponse = {
        success: false,
        error: 'Password must be at least 6 characters long'
      }
      return new Response(
        JSON.stringify(errorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`🔐 Verifying password reset token...`)

    // Check if token exists and is valid
    const tokenData = resetTokens.get(token)
    
    if (!tokenData) {
      console.log(`❌ Invalid token: ${token.substring(0, 8)}...`)
      const errorResponse: ErrorResponse = {
        success: false,
        error: 'Invalid or expired reset token',
        message: 'The reset link has expired or is invalid. Please request a new password reset.'
      }
      return new Response(
        JSON.stringify(errorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if token has expired
    if (Date.now() > tokenData.expires) {
      resetTokens.delete(token)
      console.log(`⏰ Expired token for: ${tokenData.email}`)
      const errorResponse: ErrorResponse = {
        success: false,
        error: 'Reset token has expired',
        message: 'The reset link has expired. Please request a new password reset.'
      }
      return new Response(
        JSON.stringify(errorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { email } = tokenData

    console.log(`✅ Token verified for: ${email}`)

    // Delete token after successful verification (one-time use)
    resetTokens.delete(token)
    
    console.log(`🗑️ Token consumed and deleted`)

    // Return success with email and new password
    // The Flutter app will handle the actual database update
    const successResponse: SuccessResponse = {
      success: true,
      email: email,
      message: 'Token verified successfully. You can now set your new password.'
    }

    return new Response(
      JSON.stringify(successResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    console.error('❌ Unhandled error in verify-password-reset:', err)
    const msg = err instanceof Error ? err.message : String(err)
    const errorResponse: ErrorResponse = {
      success: false,
      error: 'Internal server error',
      message: msg
    }
    return new Response(
      JSON.stringify(errorResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Export for potential sharing with send-password-reset
export { resetTokens }
