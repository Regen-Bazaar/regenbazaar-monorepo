"use client";
import { useState } from "react";
import ConnectWallet from "./ConnectWallet";
import TokenDisplay from "./navbar/token-display";
import Image from "next/image";

export default function Navbar() {
  // Get wallet address from ConnectWallet component
  const [walletAddress] = useState<string | null>(null);

  // This function will be passed to ConnectWallet to update the wallet address
  // const updateWalletAddress = (address: string | null) => {
  //   setWalletAddress(address);
  // };

  return (
    <nav className="bg-black text-white">
      <div className="max-w-screen-xl flex flex-wrap items-center justify-between mx-auto p-4">
        <a
          href="https://flowbite.com/"
          className="flex items-center space-x-3 rtl:space-x-reverse"
        >
          <Image
            src="/regen_logo.png"
            width={50}
            height={50}
            className=""
            alt="Regen Logo"
          />
        </a>

        {/* Middle section for token display when wallet is connected */}
        <div className="hidden md:flex items-center justify-center">
          <TokenDisplay />
        </div>

        <div className="flex md:order-2 space-x-3 md:space-x-0 rtl:space-x-reverse">
          <ConnectWallet />

          <button
            data-collapse-toggle="navbar-cta"
            type="button"
            className="inline-flex items-center p-2 w-10 h-10 justify-center text-sm text-gray-500 rounded-lg md:hidden hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-600"
            aria-controls="navbar-cta"
            aria-expanded="false"
          >
            <span className="sr-only">Open main menu</span>
            <svg
              className="w-5 h-5"
              aria-hidden="true"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 17 14"
            >
              <path
                stroke="currentColor"
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
                d="M1 1h15M1 7h15M1 13h15"
              />
            </svg>
          </button>
        </div>
        <div
          className="items-center justify-between hidden w-full md:flex md:w-auto md:order-1"
          id="navbar-cta"
        >
          <ul className="flex flex-col font-medium p-4 md:p-0 mt-4 border border-gray-100 rounded-lg bg-gray-50 md:space-x-8 rtl:space-x-reverse md:flex-row md:mt-0 md:border-0 md:bg-white dark:bg-gray-800 md:dark:bg-gray-900 dark:border-gray-700">
            <li>
                href="#"
                className="block py-2 px-3 md:p-0 text-white rounded-sm hover:bg-gray-700 md:hover:bg-transparent md:hover:text-gray-300"
              >
                Dashboard
              </a>
                className="block py-2 px-3 md:p-0 text-gray-900 rounded-sm hover:bg-gray-100 md:hover:bg-transparent md:hover:text-blue-700 md:dark:hover:text-blue-500 dark:text-white dark:hover:bg-gray-700 dark:hover:text-white md:dark:hover:bg-transparent dark:border-gray-700"
              >
                Tokenize
              </a>
            </li>
            <li>
              <a
                href="#"
                className="block py-2 px-3 md:p-0 text-white rounded-sm hover:bg-gray-700 md:hover:bg-transparent md:hover:text-gray-300"
              >
                Sell
              </a>
            </li>
            <li>
              <a
                href="#"
                className="block py-2 px-3 md:p-0 text-white rounded-sm hover:bg-gray-700 md:hover:bg-transparent md:hover:text-gray-300"
              >
                Buy
              </a>
            </li>
            <li>
              <a
                href="#"
                className="block py-2 px-3 md:p-0 text-white rounded-sm hover:bg-gray-700 md:hover:bg-transparent md:hover:text-gray-300"
              >
                Stake
              </a>
            </li>
          </ul>
        </div>

        {/* Mobile token display */}
        <div className="w-full md:hidden mt-4">
          <TokenDisplay />
        </div>
      </div>
    </nav>
  );
}
