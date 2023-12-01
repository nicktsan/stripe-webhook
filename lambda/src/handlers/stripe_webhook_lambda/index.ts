// Import required AWS SDK clients and commands for Node.js. Note that this requires
// the `@aws-sdk/client-ses` module to be either bundled with this code or included
// as a Lambda layer.
// import { SES, SendEmailCommand } from "@aws-sdk/client-ses";
// import Stripe from "stripe"
import { SQSHandler, SQSEvent } from "aws-lambda";

// const ses = new SES();
// const stripe = new Stripe(process.env.STRIPE_SECRET ?? '', {
//     apiVersion: '2023-10-16',
// });

// const handler = async (event: ) => {
const handler: SQSHandler = async (event: SQSEvent/*, context*/) => {
    event.Records.forEach((record) => {
        console.log('message attributes ', record.messageAttributes);
        const payload = JSON.parse(record.body)
        console.log("Processing webhook's payload: ", payload.body)
    });
    console.log(event);
    // const response = {
    //     statusCode: 200,
    //     body: JSON.stringify('webhook processed'),
    // };
    return;
    // return response
    // console.log('EVENT: \n' + JSON.stringify(event, null, 2));
    // return context.logStreamName;
    // await stripe.customers.create({
    //     description: 'Movie App customer',
    //     email: event.request.userAttributes.email
    //     // metadata: {
    //     //     userId
    //     // }
    // });
    // const customerJson = JSON.stringify(customer)
    // return customerJson;
    //You must return the event to prevent Unrecognizable lambda output if this function is used as a post confirmation trigger
    // return event
    // if (event.request.userAttributes.email) {
    //     // await sendTheEmail(
    //     //     event.request.userAttributes.email,
    //     //     `Congratulations ${event.userName}, you have been confirmed.`
    //     // );
    // }
    // return event;
};

// const sendTheEmail = async (to, body) => {
//     const eParams = {
//         Destination: {
//             ToAddresses: [to],
//         },
//         Message: {
//             Body: {
//                 Text: {
//                     Data: body,
//                 },
//             },
//             Subject: {
//                 Data: "Cognito Identity Provider registration completed",
//             },
//         },
//         // Replace source_email with your SES validated email address
//         Source: "<source_email>",
//     };
//     try {
//         await ses.send(new SendEmailCommand(eParams));
//     } catch (err) {
//         console.log(err);
//     }
// };

export { handler };