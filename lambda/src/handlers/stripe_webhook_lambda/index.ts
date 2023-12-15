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
    stripe = getStripe(stripe);
    eventbridge = getEventbridge(eventbridge);
    if (!stripe) {
        console.info("stripe is null. Nothing processed.")
    }
    else if (!eventbridge) {
        console.info("Eventbridge is null. Nothing processed.")
    }
    else {
        for (const message of event.Records) {
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
                            DetailType: eventType, //process.env.DETAIL_TYPE,
                            EventBusName: process.env.STRIPE_EVENT_BUS,
                            Source: process.env.STRIPE_LAMBDA_EVENT_SOURCE,
                            Time: new Date
                        }
                    ]
                }
                const result = await eventbridge.putEvents(params).promise()
                console.log(result)
            }
        }
    }
};

export { handler };