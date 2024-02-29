// Import required AWS SDK clients and commands for Node.js. Note that this requires
// the `@aws-sdk/client-ses` module to be either bundled with this code or included
// as a Lambda layer.
import { SQSHandler, SQSEvent/*, Context */ } from "aws-lambda";
import { getEventbridge, getStripe, verifyMessageAsync } from "/opt/nodejs/utils";
import Stripe from "stripe";
import AWS from "aws-sdk"

let stripe: Stripe | null;
AWS.config.update({ region: process.env.AWS_REGION })
let eventbridge: AWS.EventBridge | null;

const handler: SQSHandler = async (event: SQSEvent/*, context: Context*/): Promise<void> => {
    //If there is no stripe instance, create a new one. Otherwise, use the existing one.
    stripe = getStripe(stripe);
    //If there is no eventbridge instance, create a new one. Otherwise, use the existing one.
    eventbridge = getEventbridge(eventbridge);
    if (!stripe) {
        console.info("stripe is null. Nothing processed.")
    }
    else if (!eventbridge) {
        console.info("Eventbridge is null. Nothing processed.")
    }
    else {
        //loop through each message from the SQSEvent
        for (const message of event.Records) {
            //Ensure the message comes from Stripe.
            const verified = await verifyMessageAsync(message, stripe);
            if (!verified) {
                console.log("Message not from Stripe")
            } else {
                console.log("Stripe verification successful. Publishing message to Eventbridge.")
                const payload = JSON.parse(message.body);
                const eventType = payload.type
                console.log("eventType ", eventType)
                const params = {
                    Entries: [
                        {
                            Detail: JSON.stringify({
                                "metadata": {
                                    // enriched flag set
                                    "enrich": true,
                                },
                                "data": message.body,
                                "stripeSignature": message.messageAttributes.stripeSignature.stringValue
                            }),
                            DetailType: eventType,
                            EventBusName: process.env.STRIPE_EVENT_BUS,
                            Source: process.env.STRIPE_LAMBDA_EVENT_SOURCE,
                            Time: new Date
                        }
                    ]
                }
                //Send the events to eventbridge
                const result = await eventbridge.putEvents(params).promise()
                console.log(result)
            }
        }
    }
};

export { handler };