# Mental Health IoT Analysis Platform

This project analyzes university mental health IoT data and deploys insights via a serverless AWS platform. It includes:
1. **EDA Analysis** - Comprehensive analysis of 1,000 IoT sensor records
2. **Key Stress Indicators** - Identified top 3 features correlated with stress levels
3. **Mental Insights API** - `GET /mental-insights` endpoint returning statistical analysis
4. **Infrastructure Migration** - Complete conversion from AWS SAM to Terraform
5. **Additional Features** - Storage for daily insights and a retrieval system

## Technical Architecture

### Infrastructure Components
- **API Gateway**: RESTful endpoint management
- **AWS Lambda**: Serverless compute for all functions
- **DynamoDB**: NoSQL storage for insights and user events
- **CloudWatch**: Logging and monitoring
- **Terraform**: Infrastructure as Code

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   API Gateway   │────│  Lambda Functions │────│    DynamoDB     │
│                 │    │                  │    │                 │
│ • /mental-      │    │ • Mental Insights│    │ • User Events   │
│   insights      │    │ • TypeScript User│    │ • Daily Insights│
│ • /daily-       │    │ • Python User    │    │                 │
│   insights      │    │                  │    │                 │
│ • /user         │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Lambda Functions
1. **Mental Insights Lambda** (Node.js): Statistical analysis endpoint
2. **TypeScript Lambda** (Node.js): User creation with PostgreSQL integration
3. **Python Lambda** (Python 3.11): User creation with demo responses

### Database Strategy
- **Current**: Mock responses for demo purposes
- **Production Ready**: Environment variables are configured for RDS PostgreSQL
- **Migration Path**: Update PGHOST environment variable to RDS endpoint

## Data Analysis Methodology & Findings

### Dataset Overview
- **Source**: University campus IoT sensors
- **Timeframe**: May 2024
- **Locations**: 3 campus monitoring sites (IDs: 103-105)
- **Sensors**: 12 environmental and physiological metrics

### Correlation Analysis Process
1. **Data Cleaning**: Filtered 1,000 complete records from raw dataset
2. **Feature Selection**: 9 quantitative variables analyzed for stress correlation
3. **Statistical Testing**: Pearson correlation coefficients calculated
4. **Significance Testing**: p-values computed for all correlations
5. **Ranking**: Features sorted by absolute correlation strength

### Key Insights for Campus Mental Health
- **Environmental Impact**: Air quality shows stronger correlation (0.56) than noise or lighting
- **Behavioral Patterns**: Sleep hours more predictive than mood scores
- **Direct Assessment**: Mental health status remains strongest single predictor
- **Intervention Opportunities**: Top 3 features provide actionable improvement areas

### Top 3 Stress Indicators Identified:

1. **Mental Health Status** (r = 0.8253) - Primary stress predictor
2. **Air Quality Index** (r = 0.5616) - Environmental factor with significant impact  
3. **Sleep Hours** (r = -0.4435) - Sleep deprivation strongly correlates with stress

### Statistical Significance:

- **Sample Size**: 1,000 complete IoT sensor readings
- **Methodology**: Pearson correlation analysis
- **Confidence Level**: 95% (p < 0.001 for top 3 features)
- **High Stress Cases**: 21% of readings above stress threshold (210/1000)

## File Directory

```
mental-health-iot/
├── README.md                          # Complete project documentation
├── .gitignore                         # Git ignore configuration
├── main.tf                            # Terraform infrastructure (converted from SAM)
├── deploy.sh                          # Automated deployment script
├── mental_insights.js                 # Mental health analysis Lambda function
├── university_mental_health_iot_dataset.csv  # Source dataset (1000 records)
│
├── ts-lambda/                         # TypeScript Lambda (preserved from original)
│   ├── app.ts                        # User creation handler
│   ├── package.json                  # Node.js dependencies
│   └── tsconfig.json                # TypeScript configuration
│
├── py-lambda/                        # Python Lambda (updated for demo)
│   ├── app.py                       # User creation handler (DB-agnostic)
│   └── requirements.txt             # Python dependencies (simplified)
│
└── db/                              # Database schema (for future RDS integration)
    └── init.sql                     # PostgreSQL table definitions
```

## Deployment Directions

### Prerequisites
- AWS CLI configured with appropriate IAM permissions
- Terraform >= 1.0
- Node.js >= 18
- Python >= 3.11

### Scripted Deployment 
```bash
# Clone repository and make deployment script executable
git clone <this-repository>
cd mental-health-iot
chmod +x deploy.sh

# Deploy complete infrastructure
./deploy.sh
```

The deployment script automatically:
- Validates all prerequisites
- Builds TypeScript and Python Lambda functions
- Deploys AWS infrastructure via Terraform
- Tests all API endpoints
- Displays complete API documentation

### Manual Deployment (Alternative)
```bash
# Build Lambda functions
cd ts-lambda && npm install && npx tsc && cd ..
mkdir -p py-lambda-build && cp py-lambda/app.py py-lambda-build/
cd py-lambda-build && zip -r ../py-lambda.zip . && cd ..

# Deploy infrastructure
terraform init
terraform plan -out=tfplan  
terraform apply tfplan
```
## Troubleshooting

### Potential Issues
**Terraform Permission Errors:**
```bash
aws sts get-caller-identity  # Verify AWS credentials
```

**Lambda Function Errors:**
```bash
aws logs filter-log-events --log-group-name "/aws/lambda/mental-health-iot-py-lambda"
```

**API Gateway 502 Errors:**
- Check Lambda function permissions
- Verify API Gateway integration configuration
- Review CloudWatch logs for detailed error messages

### Clean Up Resources
```bash
terraform destroy -auto-approve
```

## API Endpoints

**Base URL**: `https://{api-id}.execute-api.us-east-1.amazonaws.com/dev`

### Core Mental Health Analysis
```bash
# Get statistical analysis and stress indicators
GET /mental-insights

# Get comprehensive summary statistics
GET /summary-stats

# Get visualization-ready data (charts, graphs, heatmaps)
GET /visualizations
```
**Mental Insights Response:**
```json
{
  "top_stress_features": ["mental_health_status", "air_quality_index", "sleep_hours"],
  "correlations": {
    "mental_health_status": 0.8253,
    "air_quality_index": 0.5616,
    "sleep_hours": -0.4435
  },
  "recommendations": {
    "mental_health_status": "Monitor mental health status closely...",
    "air_quality_index": "Poor air quality significantly increases stress...",
    "sleep_hours": "Insufficient sleep strongly correlates with higher stress..."
  }
}
```

**Summary Statistics Response:**
```json
{
  "summary_statistics": {
    "stress_level_stats": {
      "mean": 39.09,
      "median": 39.0,
      "std_deviation": 18.52,
      "distribution": {
        "low_stress": {"count": 580, "percentage": 58.0},
        "moderate_stress": {"count": 210, "percentage": 21.0},
        "high_stress": {"count": 210, "percentage": 21.0}
      }
    },
    "environmental_stats": {
      "air_quality_index": {"mean": 85.45, "median": 86.0},
      "sleep_hours": {"mean": 6.42, "below_recommended": 65.0}
    }
  }
}
```

**Visualization Data Response:**
```json
{
  "visualizations": {
    "correlation_heatmap": {
      "features": ["mental_health_status", "air_quality_index", "sleep_hours"],
      "correlations": [0.8253, 0.5616, -0.4435]
    },
    "stress_distribution": {
      "bins": [
        {"range": "1-10", "count": 58, "percentage": 5.8},
        {"range": "31-40", "count": 204, "percentage": 20.4}
      ]
    },
    "feature_importance": {
      "data": [
        {"feature": "Mental Health Status", "correlation": 0.8253, "importance": "Critical"},
        {"feature": "Air Quality Index", "correlation": 0.5616, "importance": "High"}
      ]
    }
  }
}
```

### Managing Daily Insights 
```bash
# Get daily stress patterns
GET /daily-insights?date=2024-05-22

# Store daily analysis results
POST /daily-insights
Content-Type: application/json
{"date": "2024-05-22"}
```

## Example API Usage

### Get Complete Analysis Suite
```bash
# Statistical analysis with correlations and recommendations
curl https://your-api-url/dev/mental-insights

# Comprehensive summary statistics for all variables
curl https://your-api-url/dev/summary-stats  

# Chart-ready visualization data (heatmaps, histograms, scatter plots)
curl https://your-api-url/dev/visualizations

# Daily stress patterns and trends
curl https://your-api-url/dev/daily-insights
```

### Visualization Data Usage
The `/visualizations` endpoint provides ready-to-use data for:
- **Correlation Heatmap**: Feature relationships with stress levels
- **Stress Distribution**: Histogram showing frequency of stress levels
- **Feature Importance**: Bar chart of top predictors
- **Environmental Trends**: Scatter plots showing variable relationships

This was designed for integration with Chart.js, D3.js, or other popular visualization libraries.


### User Management (Legacy from Original SAM Template)
```bash
# Create user via TypeScript Lambda
POST /user
Content-Type: application/json
{"id": "user-123", "name": "John Doe"}

# Create user via Python Lambda  
POST /user-python
Content-Type: application/json
{"id": "user-456", "name": "Jane Smith"}
```