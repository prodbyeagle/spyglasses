import type { Metadata, Viewport } from 'next';
import { Inter } from 'next/font/google';

import './globals.css';

const SITE_TITLE = 'SpyGlasses';
const SITE_DESCRIPTION =
	'A lightweight macOS menu bar app that shows live network throughput at a glance.';

export const metadata: Metadata = {
	title: {
		default: SITE_TITLE,
		template: '%s - SpyGlasses',
	},
	description: SITE_DESCRIPTION,
	applicationName: SITE_TITLE,
	creator: 'prodbyeagle',
	publisher: 'prodbyeagle',
	keywords: [
		'SpyGlasses',
		'macOS',
		'menu bar',
		'network monitor',
		'speed test',
		'SwiftUI',
	],
	icons: {
		icon: '/app-icon.svg',
		apple: '/app-icon.svg',
	},
	openGraph: {
		title: SITE_TITLE,
		description: SITE_DESCRIPTION,
		type: 'website',
	},
	twitter: {
		card: 'summary',
		title: SITE_TITLE,
		description: SITE_DESCRIPTION,
	},
};

export const viewport: Viewport = {
	colorScheme: 'light dark',
	themeColor: [
		{ media: '(prefers-color-scheme: light)', color: '#f7f2e8' },
		{ media: '(prefers-color-scheme: dark)', color: '#191711' },
	],
};

const inter = Inter({
	variable: '--font-inter',
	subsets: ['latin'],
});

export default function RootLayout({
	children,
}: Readonly<{
	children: React.ReactNode;
}>) {
	return (
		<html lang='en'>
			<body
				className={`${inter.variable} bg-background font-sans font-medium tracking-tight text-text antialiased`}>
				{children}
			</body>
		</html>
	);
}
