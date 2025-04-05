"use client"

import { supabase } from "@/utils/supabaseClient"
import { useEffect, useState } from "react"



export default function Page() {
    const [userData, setUserData] = useState([])


    useEffect(() => {


        const fetchUserData = async () => {

            const {data, error} = await supabase
            .from('users')
            .select('*')





            if (error) {
                console.log("error fetching data:",  error )
                setUserData([])
            }

            if (data) {
                setUserData(data)
                console.log("data fetched", data)
            }


        }

        fetchUserData()


    },  [])





    return (
        <div className=" w-full h-screen flex flex-col items-center justify-center gap-5"  >
            page


            {userData.map((user, index) => (
                <div key={index} >
                    <h1>The wallet address: {user.wallet_address} </h1>
                    <h2>The name: {user.name} </h2>
                </div>
            ))}
        </div>
    )
}