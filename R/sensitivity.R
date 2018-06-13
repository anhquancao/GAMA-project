file <- "/home/quan/gama_workspace/ProjectUSTH-LUP/models/resVar.csv"
print(file)
dataexf <- read.table(file, header=T, sep=",", dec=".")
summary(dataexf)
aovexf <- aov(GDP.per.capita ~ Land.price * Prob.change * Risk.control, data = dataexf)
summary(aovexf)
round(summary(aovexf)[[1]][2]/sum(summary(aovexf)[[1]][2])*100,2)