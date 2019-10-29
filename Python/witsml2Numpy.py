from suds.client import Client
import untangle
import functools
import numpy as np
from dateutil.parser import parse as dateParser
import calendar
from pprint import pprint

def toTimestamp(d):
  return calendar.timegm(d.timetuple())


def csvToVector (commaSeperatedData, csvUnits):
  stringArr = commaSeperatedData.cdata.split(",")
  units =  csvUnits.split(",")
  objectArr=[]

  if("unitless" == units[0].lower()):
    index=dateParser(stringArr[0])
    objectArr.append(toTimestamp(index))
  else:
    objectArr.append(float(stringArr[0]))

  numColumns=len(stringArr)

  for i in range(numColumns):
    if(i==0):
      continue
    if('unitless' != units[i].lower()):
    #  print(str(stringArr[i]) + " = "  +str(float(stringArr[i])))
      objectArr.append(float(stringArr[i]))
    else:
      objectArr.append(stringArr[i])

  return objectArr

#Remember to add your own credentials and endpoint. KDI might have an demo server you can use
client=Client("file:..\WMLS.wsdl", username="myUserName", password="myPassWord")
client.options.location = "https://MY_STORE_ENDPOINT/store/witsml"

#Are we authenticated to use the endpoint, and which version is supported?
print(client.service.WMLS_GetVersion())

#ADJUST this query to match data in your own store
query="""<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<logs version="1.4.1.1" xmlns="http://www.witsml.org/schemas/1series">
  <log uidWell="ETP_DEMO-0" uidWellbore="WellEtpTest4" uid="1239ad7b-0e58-486e-a262-f10916b6206a">
    <nameWell />
    <nameWellbore />
    <name />   
    <startDateTimeIndex>2019-10-18T11:57:41.000Z</startDateTimeIndex>
    <logData>
      <mnemonicList />
      <unitList />
      <data />
    </logData>
  </log>
</logs>"""



#Pretty print 
np.set_printoptions(suppress=True,
   formatter={'float_kind':'{:0.2f}'.format}, linewidth=130)

rawRes = client.service.WMLS_GetFromStore("log", query, "", "")
xmlResponse = untangle.parse(rawRes.XMLout)

logData = xmlResponse.logs.log.logData
mnemonicList = logData.mnemonicList
units = logData.unitList
data =np.array(list( map(functools.partial(csvToVector, csvUnits=units.cdata), logData.data)))



def arrayToList(arr):
    if type(arr) == type(np.array):
        #If the passed type is an ndarray then convert it to a list and
        #recursively convert all nested types
        return arrayToList(arr.tolist())
    else:
        #if item isn't an ndarray leave it as is.
        return arr



print(data.shape)
print(len(logData.data))
print(len(units.cdata.split(",")))


print(mnemonicList)
print(logData.data[0].cdata)
pprint(arrayToList(data[0,:]))


print(logData.data[len(logData.data)-1].cdata)
pprint(arrayToList(data[-1,:]))
 