import Stripe from "stripe";
import { SQSRecord } from "aws-lambda";
import AWS from "aws-sdk"

const getEventbridge = (eventbridge: AWS.EventBridge | null): AWS.EventBridge | null => {
    //if no stripe instance, instantiate a new stripe instance. Otherwise, return the existing stripe instance without
    //instantiating a new one.
    if (!eventbridge) {
        eventbridge = new AWS.EventBridge()
        // console.log("Instantiated a new Eventbridge object.")
    } else {
        // console.log("Found an existing Eventbridge object instance.")
    }
    return eventbridge;
};

const getStripe = (stripe: Stripe | null): Stripe | null => {
    //if no stripe instance, instantiate a new stripe instance. Otherwise, return the existing stripe instance without
    //instantiating a new one.
    if (!stripe) {
        stripe = new Stripe(process.env.STRIPE_SECRET!, {
            apiVersion: '2023-10-16',
        });
        // console.log("Instantiated a new Stripe object.")
    } else {
        // console.log("Found an existing Stripe object instance.")
    }
    return stripe;
};

//Ensures the message is a genuine stripe message
async function verifyMessageAsync(message: SQSRecord, stripe: Stripe | null): Promise<boolean> {
    const payload = message.body;
    const sig = message.messageAttributes.stripeSignature.stringValue
    console.log('message attributes ', message.messageAttributes);
    console.log('stripe signature ', sig);
    console.log(`Processed message ${payload}`);
    let event;
    try {
        event = stripe?.webhooks.constructEvent(payload, sig!, process.env.STRIPE_SIGNING_SECRET!);
    } catch (err: unknown) {
        if (err instanceof Error) {
            console.error(`Webhook Error: ${err.message}`);
        }
        return false
    }
    return true
}

export { getEventbridge, getStripe, verifyMessageAsync }