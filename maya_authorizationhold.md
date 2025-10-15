How to create a hold or authorized transaction with Maya Checkout API endpoint
This is a sample recipe to show how to create an authorize transaction using Create Checkout endpoint.

## Use Create Checkout API
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

## Set the rest of the required fields

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

## Execute API Call

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
