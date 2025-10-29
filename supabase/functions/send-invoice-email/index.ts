import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface DeliveryData {
  id: string
  status: string
  price: number
  tip_amount?: number
  pickup_address: string
  delivery_address: string
  created_at: string
  completed_at: string
  customers: {
    name: string
    email: string
    phone: string
  }
  drivers: {
    name: string
    vehicle_type: string
  }
}

serve(async (req) => {
  try {
    console.log('📧 Invoice email function invoked')
    
    // Parse request
    const { deliveryId } = await req.json()
    
    if (!deliveryId) {
      throw new Error('Missing deliveryId parameter')
    }
    
    if (!RESEND_API_KEY) {
      throw new Error('RESEND_API_KEY not configured')
    }
    
    console.log(`📦 Processing delivery: ${deliveryId}`)
    
    // Create Supabase client with service role key
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    
    // Fetch delivery details with related data
    const { data: delivery, error: fetchError } = await supabase
      .from('deliveries')
      .select(`
        *,
        customers(name, email, phone),
        drivers(name, vehicle_type)
      `)
      .eq('id', deliveryId)
      .single()
    
    if (fetchError) {
      console.error('❌ Error fetching delivery:', fetchError)
      throw new Error(`Failed to fetch delivery: ${fetchError.message}`)
    }
    
    if (!delivery) {
      throw new Error('Delivery not found')
    }
    
    console.log(`✅ Delivery found: ${delivery.id}`)
    console.log(`   Status: ${delivery.status}`)
    console.log(`   Customer: ${delivery.customers?.name}`)
    console.log(`   Email: ${delivery.customers?.email}`)
    
    // Verify delivery is completed
    if (delivery.status !== 'delivered') {
      throw new Error(`Delivery not completed yet (status: ${delivery.status})`)
    }
    
    // Check if invoice already sent
    if (delivery.invoice_sent) {
      console.log('⚠️ Invoice already sent, skipping')
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'Invoice already sent',
          skipped: true
        }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Validate customer email
    if (!delivery.customers?.email) {
      throw new Error('Customer email not found')
    }
    
    // Generate invoice HTML
    const invoiceHTML = generateInvoiceHTML(delivery as DeliveryData)
    
    console.log('📨 Sending email via Resend...')
    
    // Send email using Resend
    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'SwiftDash <noreply@swiftdash.com>',
        to: delivery.customers.email,
        subject: `Invoice for Delivery #${delivery.id.substring(0, 8)}`,
        html: invoiceHTML,
      }),
    })
    
    const emailResult = await emailResponse.json()
    
    if (!emailResponse.ok) {
      console.error('❌ Resend API error:', emailResult)
      throw new Error(`Resend API error: ${emailResult.message || 'Unknown error'}`)
    }
    
    console.log('✅ Email sent successfully')
    console.log(`   Email ID: ${emailResult.id}`)
    
    // Update delivery record that invoice was sent
    const { error: updateError } = await supabase
      .from('deliveries')
      .update({ 
        invoice_sent: true,
        invoice_sent_at: new Date().toISOString(),
        invoice_email_id: emailResult.id
      })
      .eq('id', deliveryId)
    
    if (updateError) {
      console.error('⚠️ Failed to update delivery record:', updateError)
      // Don't throw - email was sent successfully
    }
    
    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Invoice email sent successfully',
        emailId: emailResult.id
      }),
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' } 
      }
    )
    
  } catch (error) {
    console.error('❌ Error in send-invoice-email function:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false,
        error: error.message 
      }),
      { 
        status: 400, 
        headers: { 'Content-Type': 'application/json' } 
      }
    )
  }
})

function generateInvoiceHTML(delivery: DeliveryData): string {
  const invoiceNumber = delivery.id.substring(0, 8).toUpperCase()
  const deliveryDate = new Date(delivery.completed_at || delivery.created_at)
  const formattedDate = deliveryDate.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
  const formattedTime = deliveryDate.toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit'
  })
  
  const subtotal = delivery.price
  const tip = delivery.tip_amount || 0
  const total = subtotal + tip
  
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }
        
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
          background-color: #f5f5f5;
          padding: 20px;
          line-height: 1.6;
        }
        
        .invoice-container {
          max-width: 600px;
          margin: 0 auto;
          background-color: white;
          border-radius: 8px;
          box-shadow: 0 2px 8px rgba(0,0,0,0.1);
          overflow: hidden;
        }
        
        .header {
          background: linear-gradient(135deg, #2E4A9B 0%, #1e3a8a 100%);
          color: white;
          padding: 40px 30px;
          text-align: center;
        }
        
        .header h1 {
          font-size: 28px;
          margin-bottom: 10px;
          font-weight: 600;
        }
        
        .invoice-number {
          font-size: 16px;
          opacity: 0.9;
          margin-bottom: 5px;
        }
        
        .invoice-date {
          font-size: 14px;
          opacity: 0.8;
        }
        
        .content {
          padding: 30px;
        }
        
        .section {
          margin-bottom: 30px;
        }
        
        .section-title {
          font-size: 14px;
          color: #666;
          text-transform: uppercase;
          letter-spacing: 0.5px;
          margin-bottom: 10px;
          font-weight: 600;
        }
        
        .info-row {
          display: flex;
          justify-content: space-between;
          padding: 8px 0;
          border-bottom: 1px solid #f0f0f0;
        }
        
        .info-label {
          color: #666;
          font-size: 14px;
        }
        
        .info-value {
          color: #333;
          font-size: 14px;
          font-weight: 500;
          text-align: right;
          max-width: 60%;
        }
        
        .address-box {
          background-color: #f9fafb;
          padding: 15px;
          border-radius: 6px;
          margin-bottom: 15px;
        }
        
        .address-label {
          color: #666;
          font-size: 12px;
          text-transform: uppercase;
          letter-spacing: 0.5px;
          margin-bottom: 5px;
        }
        
        .address-text {
          color: #333;
          font-size: 14px;
          line-height: 1.5;
        }
        
        .line-items {
          margin-top: 30px;
          border-top: 2px solid #2E4A9B;
          padding-top: 20px;
        }
        
        .line-item {
          display: flex;
          justify-content: space-between;
          padding: 12px 0;
          border-bottom: 1px solid #f0f0f0;
        }
        
        .line-item-name {
          color: #333;
          font-size: 15px;
        }
        
        .line-item-price {
          color: #333;
          font-size: 15px;
          font-weight: 500;
        }
        
        .subtotal {
          display: flex;
          justify-content: space-between;
          padding: 12px 0;
          font-size: 15px;
          color: #666;
        }
        
        .total {
          display: flex;
          justify-content: space-between;
          padding: 15px 0;
          margin-top: 10px;
          border-top: 2px solid #2E4A9B;
          font-size: 20px;
          font-weight: 700;
          color: #2E4A9B;
        }
        
        .footer {
          background-color: #f9fafb;
          padding: 20px 30px;
          text-align: center;
          color: #666;
          font-size: 13px;
          line-height: 1.8;
        }
        
        .footer-logo {
          font-size: 18px;
          font-weight: 600;
          color: #2E4A9B;
          margin-bottom: 10px;
        }
        
        .footer-link {
          color: #2E4A9B;
          text-decoration: none;
        }
        
        @media (max-width: 600px) {
          body {
            padding: 0;
          }
          
          .invoice-container {
            border-radius: 0;
          }
          
          .header {
            padding: 30px 20px;
          }
          
          .content {
            padding: 20px;
          }
          
          .info-value {
            max-width: 50%;
          }
        }
      </style>
    </head>
    <body>
      <div class="invoice-container">
        <!-- Header -->
        <div class="header">
          <h1>🚀 SwiftDash</h1>
          <div class="invoice-number">Invoice #${invoiceNumber}</div>
          <div class="invoice-date">${formattedDate} at ${formattedTime}</div>
        </div>
        
        <!-- Content -->
        <div class="content">
          <!-- Customer Information -->
          <div class="section">
            <div class="section-title">Customer Information</div>
            <div class="info-row">
              <span class="info-label">Name</span>
              <span class="info-value">${delivery.customers.name}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Email</span>
              <span class="info-value">${delivery.customers.email}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Phone</span>
              <span class="info-value">${delivery.customers.phone}</span>
            </div>
          </div>
          
          <!-- Delivery Details -->
          <div class="section">
            <div class="section-title">Delivery Details</div>
            
            <div class="address-box">
              <div class="address-label">📍 Pickup Location</div>
              <div class="address-text">${delivery.pickup_address}</div>
            </div>
            
            <div class="address-box">
              <div class="address-label">📦 Delivery Location</div>
              <div class="address-text">${delivery.delivery_address}</div>
            </div>
            
            <div class="info-row">
              <span class="info-label">Driver</span>
              <span class="info-value">${delivery.drivers.name}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Vehicle</span>
              <span class="info-value">${delivery.drivers.vehicle_type}</span>
            </div>
          </div>
          
          <!-- Line Items -->
          <div class="line-items">
            <div class="line-item">
              <span class="line-item-name">Delivery Fee</span>
              <span class="line-item-price">₱${subtotal.toFixed(2)}</span>
            </div>
            
            ${tip > 0 ? `
            <div class="line-item">
              <span class="line-item-name">Driver Tip</span>
              <span class="line-item-price">₱${tip.toFixed(2)}</span>
            </div>
            ` : ''}
            
            <div class="total">
              <span>Total Amount</span>
              <span>₱${total.toFixed(2)}</span>
            </div>
          </div>
        </div>
        
        <!-- Footer -->
        <div class="footer">
          <div class="footer-logo">SwiftDash</div>
          <p>Thank you for choosing SwiftDash!</p>
          <p>For support, contact us at <a href="mailto:support@swiftdash.com" class="footer-link">support@swiftdash.com</a></p>
        </div>
      </div>
    </body>
    </html>
  `
}
