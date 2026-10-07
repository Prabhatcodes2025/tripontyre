import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { PublicContentProvider } from './services/content';
import './styles.css';
import './premium.css';
import './production.css';

ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><BrowserRouter><PublicContentProvider><App /></PublicContentProvider></BrowserRouter></React.StrictMode>);
