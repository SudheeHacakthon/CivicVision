# Architecture

## Overview
The Crowdsourced Infrastructure Monitor is a system that allows users to report infrastructure issues via a mobile app, which sends data to a backend API for processing and storage.

## Components
- **Mobile App**: Built with Flutter, captures images and sends to backend.
- **Backend API**: FastAPI server that handles predictions using TensorFlow model and stores data in MongoDB.
- **AI Model**: TensorFlow MobileNetV2 for image classification (inference only).
- **Database**: MongoDB for storing complaints and data.

## Flow
Flutter App → FastAPI → TensorFlow Model → MongoDB
