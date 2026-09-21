# Selah Bible

A simple, modern Bible reader built for focused, distraction-free reading of Scripture.

Selah provides a responsive single-page interface for navigating books, chapters, individual verses, and verse ranges. Scripture is rendered using the paragraph and poetry structure preserved by the Selah Bible API.

## Features

- Browse all 66 books of the Bible
- Navigate by book, chapter, and verse
- Select individual verses or verse ranges
- Paragraph-aware Scripture rendering
- Poetry and indentation formatting
- Shareable deep links to passages
- Responsive desktop and mobile interface
- Static hosting on Amazon S3
- CloudFront distribution
- Custom domain support
- Infrastructure managed with Terraform

## Example URLs

Selah supports direct links to books, chapters, verses, and passages using URL parameters.

### Book

```text
https://bible.jimisanchez.com/?book=JHN
```

### Chapter

```text
https://bible.jimisanchez.com/?book=JHN&chapter=3
```

### Verse

```text
https://bible.jimisanchez.com/?book=JHN&chapter=3&verse=16
```

### Passage

```text
https://bible.jimisanchez.com/?book=JHN&chapter=3&verse=16-21
```

## Architecture

```text
Browser
   │
   ▼
CloudFront
   │
   ▼
Amazon S3
   │
   │  Selah SPA
   │
   ▼
Amazon API Gateway
   │
   ▼
AWS Lambda
   │
   ▼
SQLite Bible Database
```

The frontend is intentionally lightweight. It uses HTML, CSS, and vanilla JavaScript without requiring a frontend framework or application server.

Scripture data is retrieved from the separate Selah Bible API.

## Technology

- HTML5
- CSS3
- JavaScript
- Amazon S3
- Amazon CloudFront
- Amazon Route 53
- Terraform
- AWS API Gateway
- AWS Lambda

## API

The application currently communicates with the Selah Bible API through:

```text
https://29s9bsspd2.execute-api.us-east-1.amazonaws.com
```

The API provides books, chapters, verses, verse ranges, and Scripture formatting metadata.

See the `selah-bible-api` repository for the backend implementation.

## Project Structure

```text
selah-bible-web/
├── index.html
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── README.md
└── .gitignore
```

Your Terraform layout may differ depending on how the infrastructure is organized.

## Local Development

Because the application calls an HTTPS API, the easiest way to test locally is to run a small HTTP server rather than opening `index.html` directly with a `file://` URL.

Using Python:

```bash
python3 -m http.server 8000
```

Then open:

```text
http://localhost:8000
```

## Deployment

The application can be deployed as a static site to Amazon S3 and served through CloudFront.

If the infrastructure is already provisioned, upload the application:

```bash
aws s3 cp index.html s3://YOUR_BUCKET_NAME/index.html \
  --content-type "text/html"
```

If CloudFront caching is enabled, invalidate the cached page after deployment:

```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/index.html" "/"
```

## Infrastructure

AWS infrastructure is managed with Terraform.

Typical deployment:

```bash
cd terraform

terraform init
terraform plan
terraform apply
```

Review the Terraform plan before applying infrastructure changes.

## Scripture Formatting

Selah preserves structural metadata provided by the backend Bible database.

Each verse may contain metadata such as:

```json
{
  "verse": 16,
  "reference": "JHN.3.16",
  "text": "For God so loved the world...",
  "paragraphId": 6472,
  "paragraphStyle": "p"
}
```

The frontend uses `paragraphId` to determine paragraph boundaries and `paragraphStyle` to distinguish normal prose, poetry, indentation, and other Scripture formatting.

This allows passages to be presented more naturally than simply displaying every verse as an independent block.

## Bible Translation

The current application uses the **World English Bible (WEB)**.

The World English Bible is a modern English Bible translation intended for broad public use and redistribution.

See the source distribution and its accompanying licensing information for applicable terms.

## Related Repository

The backend API, Lambda functions, SQLite database tooling, and associated infrastructure are maintained separately in:

```text
selah-bible-api
```

## Status

Selah is under active development.

Current functionality includes:

- Book navigation
- Chapter navigation
- Verse navigation
- Verse ranges
- Deep linking
- Paragraph-aware rendering
- Poetry formatting
- Responsive layout

## License

Application source code licensing is separate from the licensing and distribution terms of Bible translation data included or consumed by the project.

See the repository license and Bible source documentation for details.
