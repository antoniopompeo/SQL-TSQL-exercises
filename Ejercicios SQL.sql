/*
2. Mostrar el código, detalle de todos los artículos vendidos en el año 2012 ordenados por cantidad vendida. 
*/
SELECT	p.prod_codigo,
		p.prod_detalle,
		SUM(i.item_cantidad) AS Total_vendido
FROM [GD2015C1].[dbo].[Producto] AS p JOIN [GD2015C1].[dbo].[Item_Factura] AS i ON p.prod_codigo = i.item_producto 
	JOIN [GD2015C1].[dbo].[Factura] AS f ON i.item_numero = f.fact_numero AND i.item_sucursal = f.fact_sucursal AND i.item_tipo = f.fact_tipo
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY Total_vendido ASC
--IMPORTANTE, ACA COMO EL ITEM_FACTURA TIENE 4 PKS, HAY QUE VINCULAR TODAS LAS PKS CON TODAS LAS PKS ENTRE SI


/*
3. Realizar una consulta que muestre código de producto, nombre de producto y el
stock total, sin importar en que deposito se encuentre, los datos deben ser ordenados
por nombre del artículo de menor a mayor. 
*/
SELECT	p.[prod_codigo],
		p.[prod_detalle],
		SUM(s.[stoc_cantidad]) AS Stock_Total
FROM [GD2015C1].[dbo].[Producto] as p JOIN [GD2015C1].[dbo].[STOCK] as s ON p.[prod_codigo] = s.[stoc_producto]
GROUP BY p.[prod_codigo], p.[prod_detalle]
ORDER BY p.[prod_detalle] ASC


/*
5. Realizar una consulta que muestre código de artículo, detalle y cantidad de egresos
de stock que se realizaron para ese artículo en el año 2012 (egresan los productos
que fueron vendidos). Mostrar solo aquellos que hayan tenido más egresos que en el 2011. 
*/
SELECT 
		p.prod_codigo,
		p.prod_detalle,
		ISNULL (SUM(CASE WHEN YEAR(f.fact_fecha) = 2012 THEN i.item_cantidad ELSE 0 END),0)
FROM Producto p, Item_Factura i, Factura f
WHERE p.prod_codigo = i.item_producto
		AND i.item_numero = f.fact_numero
			AND I.item_sucursal = f.fact_sucursal
				AND i.item_tipo = f.fact_tipo
					AND YEAR(f.fact_fecha) IN (2011,2012)
GROUP BY p.prod_codigo, p.prod_detalle
HAVING ISNULL(SUM(CASE WHEN YEAR(f.fact_fecha) = 2012 THEN i.item_cantidad ELSE 0 END),0) > ISNULL(SUM(CASE WHEN YEAR(f.fact_fecha) = 2011 THEN i.item_cantidad ELSE 0 END),0)
ORDER BY p.prod_codigo


/*
Mostrar los 10 productos más vendidos en la historia y también los 10 productos
menos vendidos en la historia. Además mostrar de esos productos, quien fue el
cliente que mayor compra realizo. 
*/
SELECT	p3.prod_detalle,
		(SELECT TOP 1 f2.fact_cliente FROM Factura f2, Item_Factura i2 WHERE p3.prod_codigo = i2.item_producto AND i2.item_numero = f2.fact_numero AND I2.item_sucursal = f2.fact_sucursal AND i2.item_tipo = f2.fact_tipo GROUP BY f2.fact_cliente ORDER BY SUM(i2.item_cantidad) DESC)	
FROM Producto p3
WHERE prod_detalle IN 
		(SELECT TOP 10 p.prod_detalle
		FROM Producto p JOIN Item_Factura i ON p.prod_codigo = i.item_producto
		GROUP BY p.prod_detalle
		ORDER BY SUM(i.item_cantidad) DESC)
	OR prod_detalle IN
		(SELECT TOP 10 p.prod_detalle
		FROM Producto p LEFT JOIN Item_Factura i ON p.prod_codigo = i.item_producto
		GROUP BY p.prod_detalle
		ORDER BY SUM(i.item_cantidad) ASC)



/*
6. Mostrar para todos los rubros de articulos, codigo, detalle, cantidad de articulos de ese rubro y stock total de ese rubro de articulos.
solo tener en cuenta aquellos articulos que tengan un stock mayor al del articulo '00000000' en el deposito '00'
*/
select 
		r.rubr_id,
		r.rubr_detalle,
		Count(distinct p.prod_codigo), --porque por cada producto hay varios depositos, entonces el mismo producto aparece varias veces y lo suma repetido
		sum(s.stoc_cantidad)
From Rubro R left join Producto P on p.prod_rubro = r.rubr_id  --le tuve que poner un left join porque sino no te cuenta los articulos que tienen stock cero
	 left join STOCK S on s.stoc_producto = p.prod_codigo
group by r.rubr_id, r.rubr_detalle
having sum(s.stoc_cantidad) > isnull((select s2.stoc_cantidad from STOCK s2 where s2.stoc_producto = '00000000' and s2.stoc_deposito = '00'),0)
order by r.rubr_id




/*
7. Generar una consulta que muestre para cada articulo código, detalle, mayor precio menor precio y % de la diferencia de precios 
(respecto del menor Ej.: menor precio = 10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos artículos que posean stock.
*/
select p.prod_codigo, p.prod_detalle, max(i.item_precio) as maximo, min(i.item_precio) as minimo, ((max(i.item_precio)/max(i.item_precio)-1)*100)
from Item_Factura i, Producto p join STOCK s on s.stoc_producto = p.prod_codigo
where i.item_producto = p.prod_codigo
group by p.prod_codigo, p.prod_detalle
having (select SUM(isnull(s2.stoc_cantidad,0)) from STOCK s2 where s2.stoc_producto = p.prod_codigo ) > 0
order by p.prod_codigo



/*
8. Mostrar para el o los artículos que tengan stock en todos los depósitos,
nombre del artículo, stock del depósito que más stock tiene. 
*/
select p.prod_detalle, max(s.stoc_cantidad)
from STOCK s join Producto p on s.stoc_producto = p.prod_codigo
group by p.prod_detalle
having count(distinct s.stoc_deposito) = (select count(depo_codigo) from DEPOSITO)
order by p.prod_detalle



/*
15. Escriba una consulta que retorne los pares de productos que hayan sido vendidos
juntos (en la misma factura) más de 500 veces. El resultado debe mostrar el código
y descripción de cada uno de los productos y la cantidad de veces que fueron
vendidos juntos. El resultado debe estar ordenado por la cantidad de veces que se
vendieron juntos dichos productos. Los distintos pares no deben retornarse más de
una vez.
Ejemplo de lo que retornaría la consulta:

PROD1 DETALLE1 PROD2 DETALLE2 VECES
1731 MARLBORO KS 1 7 1 8 P H ILIPS MORRIS KS 5 0 7
1718 PHILIPS MORRIS KS 1 7 0 5 P H I L I P S MORRIS BOX 10 5 6 2 
*/
select	
		p1.prod_codigo, p1.prod_detalle,
		p2.prod_codigo, p2.prod_detalle,
		count(if1.item_numero)
from	Producto p1 , Producto p2, Item_Factura if1, Item_Factura if2
where
		p1.prod_codigo = if1.item_producto and
		p2.prod_codigo = if2.item_producto and
		-------
		if1.item_numero = if2.item_numero and
		if1.item_sucursal = if2.item_sucursal and
		if1.item_tipo = if2.item_tipo and
		-------
		p1.prod_codigo > p2.prod_codigo
group by 
		p1.prod_codigo, p1.prod_detalle,
		p2.prod_codigo, p2.prod_detalle
having count(if1.item_numero) > 500





/*

EJEMPLO DE PARCIAL SQL

Realizar una consulta SQL que retorne solamente los siguientes campos:

1) Nombre de Producto

2) Rubro del Producto

3) Año que más se vendió.

 Solamente considerar aquellos productos, cuyos rubros superen en ventas más de $ 100000 en el año 2011. 
 El resultado debe ser ordenado de mayor a menor por cantidad de facturas en la que figura.

 Armar una consulta SQL que retorne esta información.

NOTA: No se permite el uso de sub-selects en el FROM ni funciones definidas por el usuario 
*/

select 
	p.prod_detalle Producto, 
	p.prod_rubro AS Rubro,
	year(f.fact_fecha) AS Anio 
from Producto P inner join Item_Factura i on i.item_producto = p.prod_codigo inner join Factura f 
on f.fact_numero =i.item_numero and f.fact_tipo = i.item_tipo and i.item_sucursal = f.fact_sucursal
where p.prod_rubro IN (select p.prod_rubro
						from rubro r join Producto P on p.prod_rubro = R.rubr_id 
							join Item_Factura i on i.item_producto = p.prod_codigo join Factura f2 on 
							f2.fact_numero =i.item_numero and f2.fact_tipo = i.item_tipo and i.item_sucursal = f2.fact_sucursal
						where YEAR(f2.fact_fecha) =2011
						group by p.prod_rubro
						having sum(i.item_cantidad * i.item_precio)  > 100000)and
	 year(f.fact_fecha) IN (	select 
										YEAR(f3.fact_fecha)
									from Producto P join Item_Factura i on i.item_producto = p.prod_codigo 
									join Factura f3 on f3.fact_numero =i.item_numero and f3.fact_tipo = i.item_tipo and i.item_sucursal = f3.fact_sucursal
									where (i.item_cantidad * i.item_precio)  > 100000  
									)--order by (i.item_cantidad * i.item_precio) desc)
group by p.prod_detalle,p.prod_rubro,year(f.fact_fecha) 
order by ( count(distinct f.fact_numero++f.fact_sucursal++f.fact_tipo) ) desc

--select * from Item_Factura where item_producto='00000109'--4
--Se agregó el sguiente dato
-- A	0003	00090679	00001104	2040.00	200.15
--A		0003	00068710	00001104	3040.00	200.15
--select * from Factura where  YEAR(fact_fecha) =2011
--A	0003	00090679	2011-10-31 00:00:00	3	195.22	33.87	01746 
--A	0003	00068710	2010-01-23 00:00:00	4	105.73	18.33	01634 
--00000109
--select count(1) from Factura f,Item_Factura i where  I.item_numero + I.item_tipo + I.item_sucursal = F.fact_numero + F.fact_tipo + F.fact_sucursal 
--				and i.item_producto='00001104'
--				select * from Producto where prod_codigo ='00000109'









