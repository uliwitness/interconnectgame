-- the first program in every language
function main()
	session.write("Hello world, from ",_VERSION,"!\n")
	session.write("Average 1...5: ",session.durchschnitt(1,2,3,4,5),".\n")
	session.write("/script_success\r\n")
end

function foo()
	session.write("Why'd it call foo?!")
end

