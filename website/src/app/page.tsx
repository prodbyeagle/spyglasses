'use client';

import * as motion from 'motion/react-client';

import { AnimatedLink } from '@/components/animated-link';
import { SpyGlassesTitle } from '@/components/spyglasses-title';
import { WordReveal } from '@/components/word-reveal';

const FADE_EASE = [0.4, 0, 0.2, 1] as const;

const FEATURES = [
	{
		title: 'Menu bar speed',
		detail: 'Download and upload speed stay visible in the macOS menu bar.',
	},
	{
		title: 'Simple controls',
		detail: 'Auto start, update interval, and speed test controls live in one popover.',
	},
	{
		title: 'Native macOS app',
		detail: 'Small SwiftUI utility with no dashboard, login, or background clutter.',
	},
] as const;

const REQUIREMENTS = ['macOS 14+', 'Swift 5.10+', 'Speedtest CLI optional'];
const DOWNLOAD_URL = 'https://github.com/prodbyeagle/spyglasses/releases';

export default function Home() {
	const year = new Date().getFullYear();

	return (
		<main className='min-h-screen w-full px-6 py-20 sm:px-10 sm:py-28 md:px-16 lg:px-24'>
			<div className='mx-auto max-w-2xl'>
				<header className='mb-16'>
					<motion.h1
						className='text-2xl font-semibold text-text'
						initial={{ opacity: 0, y: 8 }}
						animate={{ opacity: 1, y: 0 }}
						transition={{ duration: 0.6, ease: FADE_EASE }}>
						<SpyGlassesTitle />
					</motion.h1>

					<p className='mt-4 max-w-lg break-words text-base leading-relaxed text-text-secondary'>
						<WordReveal
							text='a lightweight macOS menu bar app for live network throughput, speed tests, and quick connection checks.'
							delay={0.25}
							speed={0.035}
							duration={0.9}
						/>
					</p>

					<motion.div
						className='mt-8 flex flex-wrap gap-4 text-sm'
						initial={{ opacity: 0, y: 8 }}
						animate={{ opacity: 1, y: 0 }}
						transition={{ duration: 0.45, delay: 0.55, ease: FADE_EASE }}>
						<AnimatedLink
							href={DOWNLOAD_URL}
							external
							className='border border-text/20 px-4 py-2 text-text hover:border-text/45 hover:text-text'>
							download for macOS
						</AnimatedLink>
						<AnimatedLink
							href='https://github.com/prodbyeagle/spyglasses'
							external
							className='px-1 py-2 text-text-tertiary hover:text-text'>
							view source
						</AnimatedLink>
					</motion.div>
				</header>

				<motion.section
					className='mb-16'
					initial={{ opacity: 0 }}
					animate={{ opacity: 1 }}
					transition={{
						duration: 0.5,
						delay: 0.6,
						ease: FADE_EASE,
					}}>
					<h2 className='mb-6 text-sm uppercase tracking-widest text-text-tertiary'>
						features
					</h2>

					<div className='grid gap-5'>
						{FEATURES.map((feature, i) => (
							<motion.div
								key={feature.title}
								className='grid gap-1 border-l border-text-tertiary/20 pl-4'
								initial={{ opacity: 0, y: 10 }}
								animate={{ opacity: 1, y: 0 }}
								transition={{
									duration: 0.5,
									delay: 0.7 + i * 0.07,
									ease: FADE_EASE,
								}}>
								<h3 className='text-base font-semibold text-text'>
									{feature.title}
								</h3>
								<p className='text-sm leading-relaxed text-text-secondary'>
									{feature.detail}
								</p>
							</motion.div>
						))}
					</div>
				</motion.section>

				<motion.section
					className='mb-16'
					initial={{ opacity: 0 }}
					animate={{ opacity: 1 }}
					transition={{
						duration: 0.5,
						delay: 0.82,
						ease: FADE_EASE,
					}}>
					<h2 className='mb-6 text-sm uppercase tracking-widest text-text-tertiary'>
						requirements
					</h2>

					<ul className='flex flex-wrap gap-2'>
						{REQUIREMENTS.map((requirement) => (
							<li
								key={requirement}
								className='border border-text-tertiary/15 px-3 py-2 text-sm text-text-secondary'>
								{requirement}
							</li>
						))}
					</ul>
				</motion.section>

				<motion.section
					className='mb-16 border border-text-tertiary/15 p-5'
					initial={{ opacity: 0, y: 10 }}
					animate={{ opacity: 1, y: 0 }}
					transition={{
						duration: 0.5,
						delay: 0.9,
						ease: FADE_EASE,
					}}>
					<h2 className='text-base font-semibold text-text'>
						ready to install
					</h2>
					<p className='mt-2 text-sm leading-relaxed text-text-secondary'>
						Download the macOS build from GitHub or build it locally from source.
					</p>
					<div className='mt-5 flex flex-wrap gap-4 text-sm'>
						<AnimatedLink
							href={DOWNLOAD_URL}
							external
							className='border border-text/20 px-4 py-2 text-text hover:border-text/45 hover:text-text'>
							download
						</AnimatedLink>
						<AnimatedLink
							href='https://github.com/prodbyeagle/spyglasses'
							external
							className='px-1 py-2 text-text-tertiary hover:text-text'>
							github
						</AnimatedLink>
					</div>
				</motion.section>

				<motion.footer
					className='grid gap-4 border-t border-text-tertiary/15 pt-6 text-sm text-text-tertiary sm:grid-cols-[1fr_auto] sm:items-center'
					initial={{ opacity: 0 }}
					animate={{ opacity: 1 }}
					transition={{
						duration: 0.5,
						delay: 0.95,
						ease: FADE_EASE,
					}}>
					<p>&copy; {year} SpyGlasses. MIT licensed.</p>
					<nav className='flex flex-wrap gap-x-5 gap-y-2'>
						<AnimatedLink
							href='https://github.com/prodbyeagle/spyglasses'
							external
							className='text-sm text-text-tertiary hover:text-text'>
							github
						</AnimatedLink>
						<AnimatedLink
							href='https://prodbyeagle.dev'
							external
							className='text-sm text-text-tertiary hover:text-text'>
							prodbyeagle
						</AnimatedLink>
					</nav>
				</motion.footer>
			</div>
		</main>
	);
}
