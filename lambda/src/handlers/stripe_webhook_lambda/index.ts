// Import required AWS SDK clients and commands for Node.js. Note that this requires
// the `@aws-sdk/client-ses` module to be either bundled with this code or included
// as a Lambda layer.
import { SQSHandler, SQSEvent, Context, SQSRecord } from "aws-lambda";

// const handler = async (event: ) => {
const handler: SQSHandler = async (event: SQSEvent, context: Context): Promise<void> => {
    for (const message of event.Records) {
        await processMessageAsync(message);
    }
    console.info("done");
    // event.Records.forEach((record) => {
    //     console.log('message attributes ', record.messageAttributes);
    //     const payload = JSON.parse(record.body)
    //     console.log("Processing webhook's payload: ", payload.body)
    // });
    // console.log(event);
};

async function processMessageAsync(message: SQSRecord): Promise<void> {
    // try {
    console.log('message attributes ', message.messageAttributes);
    console.log(`Processed message ${message.body}`);
    // TODO: Do interesting work based on the new message
    await Promise.resolve(1); //Placeholder for actual async work
    // } catch (err) {
    //     console.error("An error occurred");
    //     throw err;
    // }
}



export { handler };