
const express = require("express");
const os = require("os");
const path = require("path");

const {
    CloudWatchClient,
    GetMetricStatisticsCommand,
    DescribeAlarmsCommand
} = require("@aws-sdk/client-cloudwatch");

const app = express();
const PORT = 3000;
const REGION = "us-east-1";

const cloudwatch = new CloudWatchClient({ region: REGION });

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

app.get("/health", (req, res) => {
    res.status(200).json({
        status: "healthy",
        service: "cloud-deployment-dashboard",
        timestamp: new Date().toISOString()
    });
});

app.get("/api/status", (req, res) => {
    const totalMemory = os.totalmem();
    const freeMemory = os.freemem();

    res.json({
        application: "healthy",
        hostname: os.hostname(),
        platform: os.platform(),
        uptimeSeconds: Math.floor(os.uptime()),
        memory: {
            totalMB: Math.round(totalMemory / 1024 / 1024),
            usedMB: Math.round((totalMemory - freeMemory) / 1024 / 1024),
            freeMB: Math.round(freeMemory / 1024 / 1024)
        },
        timestamp: new Date().toISOString()
    });
});

// AWS CloudWatch monitoring API
app.get("/api/aws-monitoring", async (req, res) => {
    try {
        const endTime = new Date();
        const startTime = new Date(endTime.getTime() - 30 * 60 * 1000);

        const metricResponse = await cloudwatch.send(
            new GetMetricStatisticsCommand({
                Namespace: "AWS/EC2",
                MetricName: "CPUUtilization",
                Dimensions: [
                    {
                        Name: "InstanceId",
                        Value: process.env.EC2_INSTANCE_ID
                    }
                ],
                StartTime: startTime,
                EndTime: endTime,
                Period: 300,
                Statistics: ["Average"]
            })
        );

        const datapoints = (metricResponse.Datapoints || [])
            .sort((a, b) => b.Timestamp - a.Timestamp);

        const alarmResponse = await cloudwatch.send(
            new DescribeAlarmsCommand({
                AlarmNames: ["automated-cloud-deployment-high-cpu"]
            })
        );

        const alarm = alarmResponse.MetricAlarms?.[0];

        res.json({
            cpuUtilization: datapoints.length
                ? Number(datapoints[0].Average.toFixed(2))
                : null,
            cpuTimestamp: datapoints[0]?.Timestamp || null,
            alarmName: alarm?.AlarmName || "Not found",
            alarmState: alarm?.StateValue || "UNKNOWN",
            threshold: alarm?.Threshold ?? 70,
            instanceId: process.env.EC2_INSTANCE_ID,
            region: REGION,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error("CloudWatch monitoring error:", error);
        res.status(503).json({
            error: "Unable to retrieve AWS monitoring data"
        });
    }
});

app.listen(PORT, "0.0.0.0", () => {
    console.log(`Cloud dashboard running on port ${PORT}`);
});

