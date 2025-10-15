Authorize (Hold) and Capture Payments in Maya Checkout
Overview
Some businesses prefer to authorize a payment first and then capture it later, rather than charging immediately. This gives you flexibility to:

Verify funds before providing goods or services
Delay the final charge until delivery or confirmation
Cancel the authorization if the order cannot be fulfilled
This guide walks you through how to implement Auth and Capture in Maya Checkout using the REST API.

Before You Begin
Before you start integrating, learn more About Maya Checkout and understand the key concepts for a successful integration.

Prerequisites
Confirm that the following are ready before you start:

Completed Maya Checkout Onboarding:
For direct-to-production commitment, follow the Getting Started in Maya Checkout (Maya Business Manager)
For sales-assisted, follow the Getting Started in Maya Checkout (Maya Manager 1.0)
Requested Authorize (Hold) and Capture feature activation
Access to Maya Business Manager or Maya Manager 1.0
API Keys: Public Key (pk-...) and Secret Key (sk-...)
Correct environment setup (Sandbox or Production)
A Webhook endpoint to listen for payment updates
How Auth and Capture Works
When a payment is authorized, the issuing bank places a hold on the customer’s card for the authorized amount.

Funds are released if:

You void the authorization, or
The hold period expires without a capture.
Card scheme and issuing bank rules ultimately control how holds, releases, and refunds are processed.

Enabling Authorize (Hold) and Capture in Maya Checkout
The Authorize (Hold) and Capture feature is available in Maya Checkout for card payments only.

To use Authorize (Hold) and Capture features in Maya Checkout:

Request activation from your Maya Relationship Manager before starting integration.
Once approved, implement the Authorize (Hold) and Capture flow by following this guide.
Authorization and Capture Intents
When using Authorize (Hold) and Capture in Maya Checkout, two types of intents are involved:

Authorization Intent
Represents the hold placed on the customer’s funds after completing Maya Checkout.
Each authorization intent has its own unique id.
Capture Intent
Represents the capture transaction tied to a specific authorization intent.
Each capture intent also has a unique id.
Key Rules for Capture Intents
You can create multiple capture intents for a single authorization intent, provided that:

All captures are created on the same day as the first successful capture attempt.
The total captured amount does not exceed the authorized amount.
Supported Authorization Types in Maya Checkout
You must specify the authorization type by setting the authorizationType field in your request.
Authorization rules differ in terms of capture amount and hold period.

authorizationType	Amount to Capture	Holding Period	Developer Notes
NORMAL	≤ authorized amount	6 days	Standard authorization; capture up to the authorized amount.
FINAL	= authorized amount	6 days	Must capture the full authorized amount.
PREAUTHORIZATION	≤ authorized amount	depends on the scheme	Typically used for industries like travel, lodging, or rentals. May have longer hold periods.
PREAUTHORIZATION hold periods:

Under certain conditions, preauthorizations have longer hold periods than normal authorizations.

Schemes	Holding Period
MasterCard	29 days
Visa	29 days (Lodging, Vehicle Rental, Cruise Lines) / 6 days (others)
JCB	6 days
AMEX	6 days
If an authorization is not captured or voided within the hold period, the issuing bank will automatically drop the hold and release the funds.

Limitation
Maya Checkout currently does not support:

Incremental authorizations
Extending hold periods via API
Amending the authorization amount
Capturing more than the authorized amount
Implementing Authorize (Hold) and Capture in Maya Checkout
Step 1: Build Your Integration
1.1. Create Your Checkout Button
Add a Checkout button where your customers will start the payment process.
The button should trigger a call to the Create Checkout API.
1.2. Prepare Your Response Pages
Prepare dedicated result pages to show request outcomes (e.g., success, failure, cancellation).
Host these pages in your system.
Use these page URLs in the redirectUrl object when creating a checkout.
This ensures customers are always redirected back to your platform with clear feedback on their payment status.

Step 2: Create an Authorization Intent
2.1 Prepare the Checkout request
When a customer clicks the Checkout button:

Build your request following the Create Checkout API specifications
Make sure to include:
all required fields
authorizationType (NORMAL/ FINAL / PREAUTHORIZATION) to create an authorization intent instead of a one-time payment
redirectUrl for your hosted response pages
2.2 Call the Create Checkout API
Send a POST request to /checkout/v1/checkouts
Receive checkoutId (the paymentId) and redirectUrl from Maya
2.3 Redirect to Maya Checkout
Use the redirectUrl from the response to send your customer to the Maya-hosted checkout page.
Checkout sessions are valid for 1 hour. If expired, generate a new checkout request.
How to create a hold or authorized transaction with Maya Checkout API endpoint
Open Recipe
Step 3: Capture the Authorized Transaction
3.1 Monitor Authorization Status
After the customer completes checkout, the authorization intent transitions to AUTHORIZED state.
Maya sends a webhook event confirming authorization.
See Understanding Payment Statuses in Maya Checkout to learn how payment statuses work and how they transition in Maya Checkout
3.2 Create a Capture Intent
Endpoint: POST /payments/v1/payments/{checkoutId}/capture
Include the paymentId from Step 2.2: Call the Create Checkout API
Response confirms the capture result
Capture can only proceed once the status is AUTHORIZED.

When doing Multiple Captures:
The first successful capture will transition the authorization intent to the CAPTURED state.
Additional captures can be created while the authorization intent is in the CAPTURED state.
At 11:59 PM of the day the first Capture was made, the authorization intent will transition to DONE (final state), where succeeding captures can no longer be done.
When Capturing Expired Authorizations:
If an authorization is not captured or voided before its hold period expires, it remains in AUTHORIZED but can no longer be captured
Once a capture is attempted on an expired authorization, the authorization intent transitions to CAPTURE_HOLD_EXPIRED
The request will fail and return the error PY0103 Payment is already expired
Step 4: Monitor Real-Time Transaction Events
Always validate the transaction outcome and reconcile the order status in your system with the webhook notification or GET Payment results.

4.1 Recommended: Use Webhooks
Webhooks notify your system of events (e.g., payment success, failure, cancellation).

To get started with webhooks, see Configuring Your Webhook for Maya Checkout.

4.2 Fallback: Retrieve Transaction Status
If webhooks fail (e.g., network issues), use these APIs:

GET /payments/v1/payments/{paymentId} → Retrieve by payment ID
GET /payments/v1/payment-rrns/{rrn} → Retrieve by request reference number
GET /payments/v1/payments/{paymentId}/status → Retrieve payment status
Endpoints
By now, you should understand the essentials of integrating Maya Checkout, including:

The core requirements to authorize and capture payments
Which endpoints to call during the authorize and capture flow
When to use each endpoint
Which API key (Public or Secret) is required
The table below summarizes the most relevant endpoints for a standard Maya Checkout integration.

Name	Method	Key Type	Endpoint	Description
Create Checkout	POST	Public	/checkout/v1/checkouts	Creates a checkout transaction. Returns checkoutId + redirectUrl
Capture Payment	POST	Secret	/payments/v1/payments/{paymentId}/capture	Capture authorized payment. Creates a Capture intent.
Retrieve Payment via ID	GET	Secret	/payments/v1/payments/{paymentId}	Get transaction details by paymentId.
Retrieve Payment via RRN	GET	Secret	/payments/v1/payment-rrns/{rrn}	Get transaction details using your request reference number.
Retrieve Payment Status	GET	Public	/payments/v1/payments/{paymentId}/status	Get the current status of a payment.
Cancel Payment via ID	POST	Secret	/payments/v1/payments/{paymentId}/cancel	Cancel a transaction (before it is authenticated or paid).
Create Webhook	POST	Secret	/payments/v1/webhooks	Registers a webhook URL for a specific transaction event on which the merchant wants to be notified of.


## How to create a hold or authorized transaction with Maya Checkout API endpoint

##  Use Create Checkout API

curl --request POST \
     --url https://pg-sandbox.paymaya.com/checkout/v1/checkouts \
     --header 'accept: application/json' \
     --header 'authorization: Basic PD123456789ABC=' \
     --header 'content-type: application/json'
     --data '{
  "authorizationType": "NORMAL",
  "totalAmount": {
    "value": 100,
    "currency": "PHP",
    "details": {
      "discount": 0,
      "serviceCharge": 0,
      "shippingFee": 0,
      "tax": 0,
      "subtotal": 100
    }
  },
  "buyer": {
    "firstName": "John",
    "middleName": "Paul",
    "lastName": "Doe",
    "birthday": "1995-10-24",
    "customerSince": "1995-10-24",
    "sex": "M",
    "contact": {
      "phone": "+639181008888",
      "email": "merchant@merchantsite.com"
    },
    "shippingAddress": {
      "firstName": "John",
      "middleName": "Paul",
      "lastName": "Doe",
      "phone": "+639181008888",
      "email": "merchant@merchantsite.com",
      "line1": "6F Launchpad",
      "line2": "Reliance Street",
      "city": "Mandaluyong City",
      "state": "Metro Manila",
      "zipCode": "1552",
      "countryCode": "PH",
      "shippingType": "ST" // ST - for standard, SD - for same day
    },
    "billingAddress": {
      "line1": "6F Launchpad",
      "line2": "Reliance Street",
      "city": "Mandaluyong City",
      "state": "Metro Manila",
      "zipCode": "1552",
      "countryCode": "PH"
    }
  },
  "items": [
    {
      "name": "Canvas Slip Ons",
      "quantity": 1,
      "code": "CVG-096732",
      "description": "Shoes",
      "amount": {
        "value": 100,
        "details": {
          "discount": 0,
          "serviceCharge": 0,
          "shippingFee": 0,
          "tax": 0,
          "subtotal": 100
        }
      },
      "totalAmount": {
        "value": 100,
        "details": {
          "discount": 0,
          "serviceCharge": 0,
          "shippingFee": 0,
          "tax": 0,
          "subtotal": 100
        }
      }
    }
  ],
  "redirectUrl": {
    "success": "https://www.merchantsite.com/success",
    "failure": "https://www.merchantsite.com/failure",
    "cancel": "https://www.merchantsite.com/cancel"
  },
  "requestReferenceNumber": "1551191039",
}'

## Set "authorizationType" field

curl --request POST \
     --url https://pg-sandbox.paymaya.com/checkout/v1/checkouts \
     --header 'accept: application/json' \
     --header 'authorization: Basic PD123456789ABC=' \
     --header 'content-type: application/json'
     --data '{
  "authorizationType": "NORMAL",
  "totalAmount": {
    "value": 100,
    "currency": "PHP",
    "details": {
      "discount": 0,
      "serviceCharge": 0,
      "shippingFee": 0,
      "tax": 0,
      "subtotal": 100
    }
  },
  "buyer": {
    "firstName": "John",
    "middleName": "Paul",
    "lastName": "Doe",
    "birthday": "1995-10-24",
    "customerSince": "1995-10-24",
    "sex": "M",
    "contact": {
      "phone": "+639181008888",
      "email": "merchant@merchantsite.com"
    },
    "shippingAddress": {
      "firstName": "John",
      "middleName": "Paul",
      "lastName": "Doe",
      "phone": "+639181008888",
      "email": "merchant@merchantsite.com",
      "line1": "6F Launchpad",
      "line2": "Reliance Street",
      "city": "Mandaluyong City",
      "state": "Metro Manila",
      "zipCode": "1552",
      "countryCode": "PH",
      "shippingType": "ST" // ST - for standard, SD - for same day
    },
    "billingAddress": {
      "line1": "6F Launchpad",
      "line2": "Reliance Street",
      "city": "Mandaluyong City",
      "state": "Metro Manila",
      "zipCode": "1552",
      "countryCode": "PH"
    }
  },
  "items": [
    {
      "name": "Canvas Slip Ons",
      "quantity": 1,
      "code": "CVG-096732",
      "description": "Shoes",
      "amount": {
        "value": 100,
        "details": {
          "discount": 0,
          "serviceCharge": 0,
          "shippingFee": 0,
          "tax": 0,
          "subtotal": 100
        }
      },
      "totalAmount": {
        "value": 100,
        "details": {
          "discount": 0,
          "serviceCharge": 0,
          "shippingFee": 0,
          "tax": 0,
          "subtotal": 100
        }
      }
    }
  ],
  "redirectUrl": {
    "success": "https://www.merchantsite.com/success",
    "failure": "https://www.merchantsite.com/failure",
    "cancel": "https://www.merchantsite.com/cancel"
  },
  "requestReferenceNumber": "1551191039",
}'

##  Set the rest of the required fields

curl --request POST \
     --url https://pg-sandbox.paymaya.com/checkout/v1/checkouts \
     --header 'accept: application/json' \
     --header 'authorization: Basic PD123456789ABC=' \
     --header 'content-type: application/json'
     --data '{
  "authorizationType": "NORMAL",
  "totalAmount": {
    "value": 100,
    "currency": "PHP",
    "details": {
      "discount": 0,
      "serviceCharge": 0,
      "shippingFee": 0,
      "tax": 0,
      "subtotal": 100
    }
  },
  "buyer": {
    "firstName": "John",
    "middleName": "Paul",
    "lastName": "Doe",
    "birthday": "1995-10-24",
    "customerSince": "1995-10-24",
    "sex": "M",
    "contact": {
      "phone": "+639181008888",
      "email": "merchant@merchantsite.com"
    },
    "shippingAddress": {
      "firstName": "John",
      "middleName": "Paul",
      "lastName": "Doe",
      "phone": "+639181008888",
      "email": "merchant@merchantsite.com",
      "line1": "6F Launchpad",
      "line2": "Reliance Street",
      "city": "Mandaluyong City",
      "state": "Metro Manila",
      "zipCode": "1552",
      "countryCode": "PH",
      "shippingType": "ST" // ST - for standard, SD - for same day
    },
    "billingAddress": {
      "line1": "6F Launchpad",
      "line2": "Reliance Street",
      "city": "Mandaluyong City",
      "state": "Metro Manila",
      "zipCode": "1552",
      "countryCode": "PH"
    }
  },
  "items": [
    {
      "name": "Canvas Slip Ons",
      "quantity": 1,
      "code": "CVG-096732",
      "description": "Shoes",
      "amount": {
        "value": 100,
        "details": {
          "discount": 0,
          "serviceCharge": 0,
          "shippingFee": 0,
          "tax": 0,
          "subtotal": 100
        }
      },
      "totalAmount": {
        "value": 100,
        "details": {
          "discount": 0,
          "serviceCharge": 0,
          "shippingFee": 0,
          "tax": 0,
          "subtotal": 100
        }
      }
    }
  ],
  "redirectUrl": {
    "success": "https://www.merchantsite.com/success",
    "failure": "https://www.merchantsite.com/failure",
    "cancel": "https://www.merchantsite.com/cancel"
  },
  "requestReferenceNumber": "1551191039",
}'

## Execute the API call

curl --request POST \
     --url https://pg-sandbox.paymaya.com/checkout/v1/checkouts \
     --header 'accept: application/json' \
     --header 'authorization: Basic PD123456789ABC=' \
     --header 'content-type: application/json'
     --data '{
  "authorizationType": "NORMAL",
  "totalAmount": {
    "value": 100,
    "currency": "PHP",
    "details": {
      "discount": 0,
      "serviceCharge": 0,
      "shippingFee": 0,
      "tax": 0,
      "subtotal": 100
    }
  },
  "buyer": {
    "firstName": "John",
    "middleName": "Paul",
    "lastName": "Doe",
    "birthday": "1995-10-24",
    "customerSince": "1995-10-24",
    "sex": "M",
    "contact": {
      "phone": "+639181008888",
      "email": "merchant@merchantsite.com"
    },
    "shippingAddress": {
      "firstName": "John",
      "middleName": "Paul",
      "lastName": "Doe",
      "phone": "+639181008888",
      "email": "merchant@merchantsite.com",
      "line1": "6F Launchpad",
      "line2": "Reliance Street",
      "city": "Mandaluyong City",
      "state": "Metro Manila",
      "zipCode": "1552",
      "countryCode": "PH",
      "shippingType": "ST" // ST - for standard, SD - for same day
    },
    "billingAddress": {
      "line1": "6F Launchpad",
      "line2": "Reliance Street",
      "city": "Mandaluyong City",
      "state": "Metro Manila",
      "zipCode": "1552",
      "countryCode": "PH"
    }
  },
  "items": [
    {
      "name": "Canvas Slip Ons",
      "quantity": 1,
      "code": "CVG-096732",
      "description": "Shoes",
      "amount": {
        "value": 100,
        "details": {
          "discount": 0,
          "serviceCharge": 0,
          "shippingFee": 0,
          "tax": 0,
          "subtotal": 100
        }
      },
      "totalAmount": {
        "value": 100,
        "details": {
          "discount": 0,
          "serviceCharge": 0,
          "shippingFee": 0,
          "tax": 0,
          "subtotal": 100
        }
      }
    }
  ],
  "redirectUrl": {
    "success": "https://www.merchantsite.com/success",
    "failure": "https://www.merchantsite.com/failure",
    "cancel": "https://www.merchantsite.com/cancel"
  },
  "requestReferenceNumber": "1551191039",
}'