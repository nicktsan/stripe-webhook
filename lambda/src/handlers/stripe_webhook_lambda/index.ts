// Import required AWS SDK clients and commands for Node.js. Note that this requires
// the `@aws-sdk/client-ses` module to be either bundled with this code or included
// as a Lambda layer.
import { SQSHandler, SQSEvent, Context } from "aws-lambda";
import { getStripe, verifyMessageAsync } from "/opt/nodejs/utils";
import Stripe from "stripe";

let stripe: Stripe | null;
const handler: SQSHandler = async (event: SQSEvent, context: Context): Promise<void> => {
    stripe = getStripe(stripe);
    if (!stripe) {
        console.info("stripe is null. Nothing processed.")
    }
    else {
        for (const message of event.Records) {
            const verified = await verifyMessageAsync(message, stripe);
            if (!verified) {
                console.log("Message not from Stripe")
            } else {
                console.log("Stripe verification successful.")
            }
        }
    }
};

export { handler };