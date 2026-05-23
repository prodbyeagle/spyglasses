'use client';

import { motion } from 'motion/react';

import { WordReveal } from '@/components/word-reveal';

export function SpyGlassesTitle() {
	return (
		<span className='inline-flex flex-wrap items-center gap-x-3 gap-y-2'>
			<motion.img
				src='/app-icon.svg'
				alt=''
				className='h-8 w-8 opacity-90 dark:invert sm:h-9 sm:w-9'
				initial={{ opacity: 0, scale: 0.88, rotate: -4 }}
				animate={{ opacity: 0.9, scale: 1, rotate: 0 }}
				transition={{
					duration: 0.65,
					delay: 0.08,
					ease: [0.22, 1, 0.36, 1],
				}}
			/>
			<WordReveal
				text='SpyGlasses'
				letter
				delay={0.18}
				speed={0.045}
				duration={0.7}
				position='bottom'
			/>
		</span>
	);
}
