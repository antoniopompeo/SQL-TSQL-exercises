/*EJERCICIOS DE PARCIAL*/

/*IMPLEMENTAR EL/LOS OBJETOS NECESARIOS PARA PODER REGISTRAR CUALES SON LOS PRODUCTOS QUE REQUIEREN REPONER SU STCOK.
COMO TAREA PREVENTIVA, SEMANALMENTE SE ANALIZARA ESTA INFORMACION PARA QUE LA FALTA DE STOCK NO SEA UNA TRABA AL MOMENTO DE REALIZAR UNA VENTA.
ESTO SE CALCULA TENIENDO EN CUENTA EL STOC_PUNTO_REPOSICION, ES DECIR, SI ESTE SUPERA EN UN 10% AL STOC_CANTIDAD DEBERIA REGISTRARSE EL PRODUCTO Y LA CANTIDAD A REPONER.
CONSIDERAR QUE LA CANTIDAD A REPONER NO DEBE SER MAYOR A STOC_STOCK_MAXIMO (CANT_REPONER = STOC_STOCK_MAXIMO - STOC_CANTIDAD)
*/


create table productos_a_reponer(
producto  char(8),
cant_reponer decimal(12,2),
deposito char(2)
)
go

alter procedure completar_productos_a_reponer as
begin
begin transaction
	
	delete from productos_a_reponer

	declare completar_tabla cursor for
	select stoc_producto, stoc_deposito, stoc_cantidad, stoc_punto_reposicion, stoc_stock_maximo
	from STOCK

	declare @stoc_producto char(8)
	declare @stoc_deposito char(2)
	declare @stoc_cantidad decimal(12,2)
	declare @stoc_punto_reposicion decimal(12,2)
	declare @stoc_stock_maximo decimal(12,2)

	open completar_tabla
	fetch completar_tabla into @stoc_producto, @stoc_deposito, @stoc_cantidad, @stoc_punto_reposicion, @stoc_stock_maximo

	while @@FETCH_STATUS = 0
	begin
		if ( @stoc_punto_reposicion > (@stoc_cantidad*1.1) )
		begin
		insert into productos_a_reponer values( @stoc_producto, ( @stoc_stock_maximo - @stoc_cantidad ),  @stoc_deposito)
		end

		fetch completar_tabla
		into @stoc_producto, @stoc_deposito, @stoc_cantidad, @stoc_punto_reposicion, @stoc_stock_maximo
	end	

	close completar_tabla
	deallocate completar_tabla
commit
end

--falta el isolation level y corroborar que el stock maximo no es null
select * from productos_a_reponer order by producto
select * from STOCK order by stoc_producto
update STOCK set stoc_cantidad = 125, stoc_stock_maximo = null where stoc_producto = '00000000' and stoc_deposito = '00'
exec completar_productos_a_reponer
go

/*
REALIZAR UN STORE PROCEDURE QUE RECIBA UN CODIGO DE PRODUCTO Y UNA FECHA
Y DEVUELVA LA MAYOR CANTIDAD DE DIAS CONSECUTIVOS A PARTIR DE ESA FECHA QUE EL PRODUCTO TUVO
AL MENOS LA VENTA DE UNA UNIDAD EN EL DIA, EL SISTEMA DE VENTAS ONLINE ESTA HABILITADO 24-7 POR LO QUE
DEBEN EVALUAR TODOS LOS DIAS INCLUYENDO DOMINGOS Y FERIADO.
*/

alter procedure cant_dias_consecutivos (@producto char(8), @fecha smalldatetime) as
begin
	declare @maximo int
	declare @contador int
	declare @fecha_anterior smalldatetime

	declare recorrer cursor for
	select item_producto, fact_fecha
	from Item_Factura join Factura on item_tipo = fact_tipo and item_sucursal = fact_sucursal and item_numero = fact_numero
	where item_producto = @producto and fact_fecha >= @fecha
	order by fact_fecha asc

	declare @item_producto char(8)
	declare @fact_fecha smalldatetime

	set @fecha_anterior = @fecha
	set @maximo = 0

	open recorrer
	fetch recorrer into @item_producto, @fact_fecha

	while @@FETCH_STATUS = 0
	begin
		if (@fact_fecha = dateadd(day, 1, @fecha_anterior) or @fact_fecha = @fecha_anterior)
		begin
			set @contador = @contador + 1
			if (@contador > @maximo) 
			begin
				set @maximo = @contador
			end
		end
		else
		begin
			set @contador = 0
		end

		set @fecha_anterior = @fact_fecha

		fetch recorrer
		into @item_producto, @fact_fecha
	end	

	close recorrer
	deallocate recorrer

	print @maximo
end

exec cant_dias_consecutivos @producto = '00000302', @fecha = '20000708'

select item_producto, fact_fecha from Item_Factura join Factura on item_tipo = fact_tipo and item_sucursal = fact_sucursal and item_numero = fact_numero 
order by item_producto, fact_fecha


/*
PARA ESTIMAR QUE STOCK SE NECESITA COMPRAR DE CADA PRODUCTO, SE TOMA COMO ESTIMACION LAS VENTAS DE UNIDADES PROMEDIO DE LOS ULTIMOS 3 MESES ANTERIORES A UNA FECHA.
SE SOLICITUA QUE SE GUARDE EN UNA TABLA (PRODUCTO, CANTIDAD A REPONER) EN FUNCION DEL CRITERIO ANTES MENCIONADO
*/
create table venta_promedio(
producto char(8),
cantidad_a_reponer int
)

go 

alter procedure venta_promedio_segun_fecha (@fecha smalldatetime) as
begin

	delete from venta_promedio
	
	--aca deberia ser de la tabla prodcuto
	declare recorrer cursor for
	select distinct item_producto
	from Item_Factura 
	order by item_producto asc

	declare @item_producto char(8)
	declare @promedio decimal(12,2)

	open recorrer
	fetch recorrer into @item_producto

	while @@FETCH_STATUS = 0
	begin
		set @promedio = 
		( select sum(item_cantidad)
		  from Item_Factura join Factura on item_tipo = fact_tipo and item_sucursal = fact_sucursal and item_numero = fact_numero
		  where item_producto = @item_producto and fact_fecha >= dateadd(MM, -3, @fecha)
		  group by item_producto) 
		/ 
		( select count(item_producto)
		  from Item_Factura join Factura on item_tipo = fact_tipo and item_sucursal = fact_sucursal and item_numero = fact_numero
		  where item_producto = @item_producto and fact_fecha >= dateadd(MM, -3, @fecha)
		  group by item_producto) 
 		insert into venta_promedio values (@item_producto, @promedio)

		fetch recorrer
		into @item_producto
	end

	close recorrer
	deallocate recorrer

end

exec venta_promedio_segun_fecha @fecha = '20120801'


declare @fecha smalldatetime
set @fecha = '20120801'
select sum(item_cantidad) from Item_Factura join Factura on item_tipo = fact_tipo and item_sucursal = fact_sucursal and item_numero = fact_numero where item_producto = '00001102' and fact_fecha >= dateadd(MM, -3, @fecha)
		  group by item_producto
select * from venta_promedio order by producto


/*
Se sabe que existen productos que poseen stock en un solo depósito,
realizar un stored procedure que reciba un código de producto (ya está validado previamente que es uno con un solo deposito) y una cantidad como parámetros.
El stored procedure debe actualizar el stock sumando a la cantidad lo que acaba de ingresar y en el caso de que el stock anterior
fuera negativo informe con la funcionalidad de “Print” todas las facturas emitidas en las cuales se vendió dicho producto sin tener stock existente.
*/
go
alter procedure actualizar_stock (@producto char(8), @cantidad_a_reponer decimal(12,2)) as
begin
	
	if( (select stoc_cantidad from STOCK where stoc_producto = @producto) < 0)
	begin	
		declare recorrer cursor for
		select item_numero, item_tipo, item_sucursal, fact_fecha
		from Item_Factura join Factura on item_numero = fact_numero and item_tipo = fact_tipo and item_sucursal = fact_sucursal
		where item_producto = @producto
		order by fact_fecha desc

		declare @item_numero char(8)
		declare @item_tipo char(1)
		declare @item_sucursal char(4)
		declare @fact_fecha smalldatetime

		open recorrer
		fetch recorrer into @item_numero, @item_tipo ,@item_sucursal ,@fact_fecha

		while @@FETCH_STATUS = 0
		begin
			print 'Nro Factura: ' + @item_numero + @item_tipo + ' Sucursal: ' + @item_sucursal --la fact_feha la copie al pedo, pasa que sino la tenia que convertir
			fetch recorrer
			into @item_numero, @item_tipo ,@item_sucursal ,@fact_fecha
		end
		close recorrer
		deallocate recorrer
	end
	else
	begin
		update STOCK
		set stoc_cantidad = stoc_cantidad + @cantidad_a_reponer
		where stoc_producto = @producto and stoc_cantidad > 0
	end
end

exec actualizar_stock @producto = '00009694', @cantidad_a_reponer = 100

select stoc_producto
	from STOCK s
	join Item_Factura i on s.stoc_producto = i.item_producto
	group by stoc_producto
	having count(stoc_deposito) =1

select * from STOCK where stoc_producto = '00009694'

update STOCK
	set stoc_cantidad = -100
		where stoc_producto = '00009694'

select * from Item_Factura where item_numero = '00092674' and item_sucursal = '0003' and item_tipo = 'A' and item_producto = '00009694'

select * from Item_Factura where item_producto = '00009694'


/*
Implementar el/los Objetos necesarios para controlar que la maxima cantidad de empleados por DEPARTAMENTO sea 60
Considerar que los datos actuales cumplen esa restriccion
*/
go
create trigger control_cant_empleados on Empleado after update, insert as
begin
	declare conteo cursor for
	select distinct empl_departamento
	from Inserted

	declare @departamento numeric(6,0)

	open conteo
	fetch conteo into @departamento

	while @@FETCH_STATUS = 0
	begin
		if( 
		(select count(distinct empl_codigo) from Empleado where empl_departamento = @departamento group by empl_departamento)
		+
		(select count(distinct empl_codigo) from inserted where empl_departamento = @departamento group by empl_departamento)
		> 60)
		begin
			rollback
			print 'no puede haber mas de 60 empleados por departamento'
			return
		end
		fetch conteo
		into @departamento
	end	
	close conteo
	deallocate conteo

	insert into Empleado select * from inserted
end


/*
Se necesita realizar una migracion de los codigos de productos a una nueva codificacion que va a ser
A + substring(prod_codigo,2,7).
implemente el/los objetos para llevar a cabo la migracion.
nota: no se pueden eliminar las constraint
*/
go
CREATE PROCEDURE MigrarCodigoProd AS
BEGIN
	-- Disable the constraints:
	ALTER TABLE dbo.Producto NOCHECK CONSTRAINT ALL
	ALTER TABLE dbo.Composicion NOCHECK CONSTRAINT ALL
	ALTER TABLE dbo.Stock NOCHECK CONSTRAINT ALL
	ALTER TABLE dbo.Item_Factura NOCHECK CONSTRAINT ALL

	UPDATE dbo.Producto
	SET prod_codigo = 'A' + substring(prod_codigo,2,7);

	UPDATE dbo.Composicion
	SET comp_producto = 'A' + substring(comp_producto,2,7);

	UPDATE dbo.Composicion
	SET comp_componente = 'A' + substring(comp_componente,2,7);

	UPDATE dbo.Stock
	SET stoc_producto = 'A' + substring(stoc_producto,2,7);

	UPDATE dbo.Item_Factura
	SET item_producto = 'A' + substring(item_producto,2,7);

	-- Re-enable the constraints:
	ALTER TABLE dbo.Producto WITH CHECK CHECK CONSTRAINT ALL
	ALTER TABLE dbo.Composicion WITH CHECK CHECK CONSTRAINT ALL
	ALTER TABLE dbo.Stock WITH CHECK CHECK CONSTRAINT ALL
	ALTER TABLE dbo.Item_Factura WITH CHECK CHECK CONSTRAINT ALL
END
GO

EXECUTE MigrarCodigoProd
GO

/*
Se necesita realizar una migración de los códigos de productos a una nueva codificación que va a ser A + substring(prod_codigo,2,7).
Implemente el/los objetos para llevar a cabo la migración.
*/

--alter procedure migracion as
create procedure migracion as
BEGIN

	alter table Producto nocheck constraint all
	alter table Composicion nocheck constraint all
	alter table Item_Factura nocheck constraint all
	alter table STOCK nocheck constraint all

	UPDATE Producto
	SET prod_codigo = 'A' + substring(prod_codigo,2,7)

	UPDATE Composicion
	SET comp_producto = 'A' + substring(comp_producto,2,7)

	UPDATE Composicion
	SET comp_componente = 'A' + substring(comp_componente,2,7)

	UPDATE Item_Factura
	SET item_producto = 'A' + substring(item_producto,2,7)

	UPDATE STOCK
	SET stoc_producto = 'A' + substring(stoc_producto,2,7)

	alter table Producto with check check constraint all
	alter table Composicion with check check constraint all
	alter table Item_Factura with check check constraint all
	alter table STOCK with check check constraint all
END
go

exec migracion
go


/*
select * from producto
select * from Composicion
select * from item_factura
select * from stock
*/

/*
Dada una tabla llamada TOP_Cliente, en la cual esta el cliente que mas unidades compro de todos los productos en todos los tiempos
se le pide que implemente el/los objetos necesarios para que la misma este siempre actualizada.
la estructura de la tabla es TOP_CLIENTE(ID_CLIENTE, CANTIDAD_TOTAL_COMPRADA) y actualmente tiene datos y cumplen con la condicion.
*/

create table TOP_CLIENTE (
	id_cliente char(6),
	cantidad decimal(12,0)
);
INSERT INTO TOP_CLIENTE VALUES ('01634', 12)
GO
create trigger actualizar_top_cliente on item_factura after update, delete, insert as
begin
	begin transaction
		DELETE FROM TOP_CLIENTE
		INSERT INTO  TOP_CLIENTE (id_cliente, cantidad)
		SELECT TOP 1
			fact_cliente,		
			sum(item_cantidad)
		FROM Factura 
		JOIN Item_Factura on item_tipo = fact_tipo AND item_numero = fact_numero AND item_sucursal = fact_sucursal
		GROUP BY fact_cliente
		ORDER BY 2 DESC
	commit
end



/*
Agregar el/los objetos necesarios para nunca se pueda realizar una venta con un precio distinto al que se encuentre en la tabla productos
*/
go
CREATE TRIGGER TR_CONTROL_VENTA_INSERT ON Item_Factura INSTEAD OF INSERT, UPDATE AS
BEGIN
	DECLARE @item_tipo char(1)
	DECLARE @item_sucursal char(4)
	DECLARE @item_numero char(8)
	DECLARE @item_producto char(8)
	DECLARE @item_cantidad decimal(12,2)
	DECLARE @item_precio decimal(12,2)

	DECLARE mi_cursor CURSOR FOR
	SELECT item_tipo,item_sucursal,item_numero,item_producto,item_cantidad,item_precio FROM inserted

	OPEN mi_cursor 
	FETCH mi_cursor INTO @item_tipo, @item_sucursal,@item_numero,@item_producto,@item_cantidad,@item_precio
        
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		IF EXISTS( SELECT p.prod_codigo, prod_precio FROM Producto p where prod_codigo = @item_producto and prod_precio = @item_precio)
		BEGIN
			INSERT INTO Item_Factura (item_tipo,item_sucursal,item_numero,item_producto,item_cantidad,item_precio)
			VALUES (@item_tipo,@item_sucursal,@item_numero,@item_producto,@item_cantidad,@item_precio)
		END
		ELSE
		BEGIN
			PRINT 'EL PRECIO NO COINCIDE CON EL PRESENTE EN LA TABLA PRODUCTO, NO SE INSERTA'
			ROLLBACK
			RETURN --aca termina el prog, deberia seguir pero indicando que producto no guardo, o directamente tirar un rollback!!!
		END

		FETCH mi_cursor INTO @item_tipo, @item_sucursal,@item_numero,@item_producto,@item_cantidad,@item_precio
	END 
	CLOSE mi_cursor 
	DEALLOCATE mi_cursor
END
GO


--SI QUISIERA SEPARAR EL UPDATE DLE INSERT, PODRIA SACAR EL UPDATE AL DE ARRIBA Y PONERLO ABAJO ASI:
CREATE TRIGGER TR_CONTROL_VENTA_UPDATE ON Item_Factura INSTEAD OF UPDATE AS
begin
	DECLARE @item_tipo char(1)
	DECLARE @item_sucursal char(4)
	DECLARE @item_numero char(8)
	DECLARE @item_producto char(8)
	DECLARE @item_cantidad decimal(12,2)
	DECLARE @item_precio decimal(12,2)

	DECLARE mi_cursor2 CURSOR FOR
	SELECT item_tipo,item_sucursal,item_numero,item_producto,item_cantidad,item_precio FROM inserted
	
	OPEN mi_cursor2
	FETCH mi_cursor2 INTO @item_tipo,@item_sucursal,@item_numero,@item_producto,@item_cantidad,@item_precio
        
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		IF EXISTS(SELECT p.prod_codigo, prod_precio FROM Producto p where prod_codigo = @item_producto and prod_precio = @item_precio)
		BEGIN
			UPDATE Item_Factura
			set item_precio = @item_precio, item_cantidad = @item_cantidad
			where item_numero = @item_numero and
			      item_sucursal = @item_sucursal and
				  item_tipo = @item_tipo and
				  item_producto = @item_producto
		END
		ELSE
		BEGIN
			PRINT 'EL PRECIO NO COINCIDE CON EL PRESENTE EN LA TABLA PRODUCTO, NO SE ACTUALIZA'
			ROLLBACK
			RETURN
		END
		FETCH mi_cursor2 INTO @item_tipo,@item_sucursal,@item_numero,@item_producto,@item_cantidad,@item_precio
    END 
	CLOSE mi_cursor2
	DEALLOCATE mi_cursor2
end


/*
Implementar el/los objetos necesarios para controlar que nunca se pueda facturar un producto si no hay stock suficiente del producto en el deposito ‘00’.
Nota: En caso de que se facture un producto compuesto, por ejemplo, combo1, deberá controlar que exista stock en el deposito ‘00’ de cada uno de sus componentes
*/
go
create trigger control_stock on item_factura after insert, update as
begin
	DECLARE @item_producto char(8)
	DECLARE @comp_cantidad decimal(12,0)
	DECLARE @comp_componente  char(8)

	DECLARE mi_cursor2 CURSOR FOR
	SELECT distinct item_producto FROM inserted
	
	OPEN mi_cursor2 
	FETCH mi_cursor2 INTO @item_producto
        
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		IF(@item_producto in (select comp_producto from Composicion))
		BEGIN
			
			DECLARE cursor_composicion CURSOR FOR 
				SELECT comp_componente, comp_cantidad FROM Composicion WHERE comp_producto = @item_producto
			OPEN cursor_composicion
			FETCH cursor_composicion INTO @comp_componente, @comp_cantidad
			WHILE @@FETCH_STATUS = 0 
			BEGIN
				if ( @comp_cantidad * (select count(item_producto) from inserted where item_producto = @item_producto group by item_producto)
				>=
				(select stoc_cantidad from STOCK where stoc_deposito = '00' and stoc_producto = @comp_componente) )
				BEGIN 
					print 'no hay suficiente stock para el componente ' + @comp_componente + ' en el deposito 00'
					ROLLBACK
					RETURN
				END
			END
			CLOSE cursor_composicion 
			DEALLOCATE cursor_composicion

		END
		ELSE
		BEGIN
			IF( (select sum(item_cantidad) from inserted where item_producto = @item_producto group by item_producto)
			>=
			(select stoc_cantidad from STOCK where stoc_deposito = '00' and stoc_producto = @item_producto)	)
			BEGIN
				PRINT 'EL Producto ' + @item_producto + ' NO Cuenta con stock en el deposito 00'
				ROLLBACK
				RETURN
			END
		END

		FETCH mi_cursor2 INTO @item_producto
    END 
	CLOSE mi_cursor2 
	DEALLOCATE mi_cursor2

	--si no se corto el ciclo es porque todos tienen stock, entonces lo almaceno
	insert into Item_Factura select * from inserted
END




/*
Realizar un stored procedure que calcule e informe la comisión de un vendedor para un determinado mes.  
Los parámetros de entrada es código de vendedor, mes y año, el primero de ellos es obligatorio y los 2 referentes al periodo pueden ingresar como nulos, 
en ese caso el periodo a calcular es el mes anterior al mes en curso.
Si el periodo a calcular es el mes anterior al mes en curso, ademas de informar lo pedido debe actualizar la comisión en la tabla de empleados.
El criterio para el comisionamiento es:
5% del total vendido tomando como importe base el valor de la factura sin los impuestos del mes a comisionar,
a esto se le debe sumar un plus de 3% mas en el caso de que sea el vendedor que mas vendió los productos nuevos en comparación al resto de los vendedores, 
es decir este plus se le aplica solo a un vendedor y en caso de igualdad se le otorga al que posea el código de vendedor mas alto. 
Se considera que un producto es nuevo cuando su primera venta en la empresa se produjo durante el mes en curso o en alguno de los 4 meses anteriores.   
De no haber ventas de productos nuevos en ese periodo, ese plus nunca se aplica.
*/

go
create procedure calcular_comision (@codigo_vendedor numeric(6,0), @mes int, @anio int) as
begin
	declare @comision decimal(12,2)
	declare @porcentaje decimal(3,2)
	declare @mejor_vendedor numeric(6,0)
	set @porcentaje = 0.05

	if (@mes = null and @anio = null)
	begin
		set @mes = (month(getdate())-1)
		set @anio = year(getdate())
	end
			
	if(	exists ( select prod_codigo 
				 from Producto p1, item_factura i1 join factura f1 on f1.fact_tipo = i1.item_tipo and f1.fact_sucursal = i1.item_sucursal and f1.fact_numero = i1.item_numero  
				 where 
						prod_codigo = i1.item_producto 
						and month(f1.fact_fecha) > (@mes-4) 
						and year(f1.fact_fecha) > @anio 
						and month(f1.fact_fecha) <= @mes 
						and	(not exists(	select p1.prod_codigo from Producto, item_factura, factura 
											where p1.prod_codigo = i1.item_producto and month(f1.fact_fecha) < (@mes-4) and year(f1.fact_fecha) <= @anio ) ) ) )
	begin
		 select top 1 fact_vendedor = @mejor_vendedor, sum(item_cantidad)
		 from factura join item_factura on fact_tipo = item_tipo and fact_sucursal = item_sucursal and fact_numero = item_numero
		 where item_producto in 
				(select prod_codigo 
				 from Producto p1, item_factura i1 join factura f1 on f1.fact_tipo = i1.item_tipo and f1.fact_sucursal = i1.item_sucursal and f1.fact_numero = i1.item_numero  
				 where 
						prod_codigo = i1.item_producto 
						and month(f1.fact_fecha) > (@mes-4) 
						and year(f1.fact_fecha) > @anio 
						and month(f1.fact_fecha) <= @mes 
						and	(not exists(	select p1.prod_codigo from Producto, item_factura, factura 
											where p1.prod_codigo = i1.item_producto and month(f1.fact_fecha) < (@mes-4) and year(f1.fact_fecha) <= @anio ) ) )
		 group by fact_vendedor
		 order by 2 desc, fact_vendedor desc 
		 if( @codigo_vendedor = @mejor_vendedor)
		 begin
			set @porcentaje = 0.08
		 end
	end
	
	set @comision = ( @porcentaje * (select sum(fact_total) from Factura where fact_vendedor = @codigo_vendedor and month(fact_fecha) = @mes and year(fact_fecha) = @anio) )

	if(@mes = (month(getdate())-1) and @anio = year(getdate()))
		update Empleado set empl_comision = @comision where empl_codigo = @codigo_vendedor
end



/*
Implementar el/los objetos y aislamientos necesarios para poder implementar el concepto de unique contraint sobre la tabla clientes, campo rsocial.
Tomar en consideración que pueden existir valores nulos y estos sí pueden estar repetidos. 
Cada vez que se quiera ingresar un valor duplicado además de no permitirlo, 
se deberá guardar en una estructura adicional el valor a insertar y fecha_hora de intento. También, 
tomar las medidas necesarias dado que actualmente se sabe que esta restricción no esta implementada.

Nota: No se puede usar la unique contraint ni cambiar la primary key para resolver este ejercicio.*/

CREATE TABLE intentos (
    id_intento INTEGER IDENTITY(1,1) PRIMARY KEY
    ,fecha DATETIME
    ,razon_social CHAR(100)
)
GO

CREATE TRIGGER razon_social_unique
ON Cliente
AFTER INSERT, UPDATE
AS
BEGIN TRANSACTION
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE 
    DECLARE @razon_social AS CHAR(100);
    DECLARE @codigo AS CHAR(6);

	declare mi_cursor cursor for
	select clie_codigo, clie_razon_social from inserted

	open mi_cursor
	fetch mi_cursor into @codigo, @razon_social


	while @@FETCH_STATUS = 0
	BEGIN
		if(@razon_social is not null) and exists (select clie_razon_social from Cliente where clie_codigo != @codigo and clie_razon_social = @razon_social)
		begin
		
			print 'No se puede insertar una razón social ya existente'
			rollback transaction

			insert into intentos(fecha, razon_social) values( getdate(), @razon_social )
			return
		end
		fetch mi_cursor into @codigo, @razon_social
	end
	close mi_cursor
	deallocate mi_cursor
COMMIT
GO





/*
Actualmente el campo fact_vendedor representa al empleado que vendio la factura. 
Implementar el/los objetos necesarios para respetar la integridad referenciales de dicho campo
suponiendo que no existe una foreign key entre ambos. 

Nota: No se puede usar una foreign key para el ejercicio, deberá buscar otro método
*/

/*RESOLUCION: 
QUE NO SE PUEDA BORRAR UN EMPLEADO QUE NO EXISTA COMO FACT_VENDEDOR 
QUE EN FACT_VENDEDOR SOLO SE PUEDAN PONER EMPLEADOS REGISTRADOS
*/





/*
2. Realizar una función que dado un artículo y una fecha, retorne el stock que existía a
esa fecha.
como el enunciado del ejercicio esta mal, el profe dijo que calculemos 
*/
go
create function fun_2 (@art char(8), @fec smalldatetime)
returns decimal(12,2)
as
begin
declare @vendidos decimal(12,2)
select @vendidos = sum(i.item_cantidad) 
from factura f join Item_Factura i on
f.fact_numero = i.item_numero and f.fact_sucursal = i.item_sucursal and f.fact_tipo = i.item_tipo
where f.fact_fecha = @fec and i.item_producto = @art
return @vendidos
end

select dbo.fun_2('00001415','20111216')




/*
1. Hacer una función que dado un artículo y un deposito devuelva un string que indique el estado del depósito según el artículo. 
Si la cantidad almacenada es menor al límite retornar “OCUPACION DEL DEPOSITO XX %” siendo XX el % de ocupación. 
Si la cantidad almacenada es mayor o igual al límite retornar “DEPOSITO COMPLETO”. 
*/

alter function fun_1 (@art char(8), @dep char(2))
returns char(50)
as
begin
	declare @estado char(100)
	declare @cant_almacenada decimal(12,2)
	declare @maximo decimal(12,2)
	declare @porcentaje decimal(12,2)  --ojo que aca me saltaba error porquele puse decimal(2,2) y necesitaba mas espacio al momento de setearlo

	select @cant_almacenada = stoc_cantidad,  @maximo = stoc_stock_maximo from STOCK where stoc_producto = @art and stoc_deposito = @dep

	if (@cant_almacenada > @maximo)
	begin
		set @estado = 'deposito completo'
	end
	else
	begin
		set @porcentaje = round(((@cant_almacenada/@maximo)*100),2)
		set @estado = 'ocupacion del deposito ' + convert(char(5), @porcentaje) + '%'
	end

	return @estado
end

select dbo.fun_1('00000030','00')
select dbo.fun_1('99999999','15')
select * from stock where stoc_cantidad > stoc_stock_maximo



/* 
3. Cree el/los objetos de base de datos necesarios para corregir la tabla empleado en caso que sea necesario. 
Se sabe que debería existir un único gerente general (debería ser el único empleado sin jefe).
Si detecta que hay más de un empleado sin jefe deberá elegir entre ellos el gerente general, el cual será seleccionado por mayor salario.
Si hay más de uno se seleccionara el de mayor antigüedad en la empresa.
Al finalizar la ejecución del objeto la tabla deberá cumplir con la regla de un único empleado sin jefe (el gerente general) y deberá retornar la cantidad de empleados que había sin jefe antes de la ejecución
*/

alter procedure fun_3 as
begin
	declare @cant_empl_sin_jefe decimal(12,2)
	declare @mayor_salario decimal(12,2)
	declare @gerente numeric(6,0)
	select @cant_empl_sin_jefe = count(empl_codigo) from Empleado where empl_jefe is null
	
	if (@cant_empl_sin_jefe > 1)
	begin
		select top 1 @mayor_salario = empl_salario from Empleado where empl_jefe is null order by empl_salario desc
	end
	
	if ((select count(empl_codigo) from Empleado where empl_jefe is null and empl_salario = @mayor_salario) > 1)
	begin
		select top 1 @gerente = empl_codigo from Empleado where empl_jefe is null and empl_salario = @mayor_salario order by empl_ingreso asc
		update Empleado
			set empl_jefe= null
			where empl_codigo = @gerente
		update Empleado
			set empl_jefe = @gerente
			where empl_jefe is null and empl_codigo !=  @gerente
	end
	else
	begin
		(select @gerente = empl_codigo from Empleado where empl_salario = @mayor_salario and empl_jefe is null)
		update Empleado
			set empl_jefe = null
			where empl_salario = @mayor_salario
		update Empleado
			set empl_jefe = 1
			where empl_jefe is null      
	end

	return @cant_empl_sin_jefe	
end	


exec dbo.fun_3
select * from Empleado order by empl_ingreso asc




/*
un ejercicio que dio el profe en clase como ejemplo de uso de un triggers instead of
crear un objeto que permita borrar un cliente y borre en cascada todos sus datos en tablas relacionadas.
*/
create trigger ej_trigger_cliente
on cliente
instead of delete
as
begin transaction
	print 'entra al trigger'

	declare aBorrar cursor for
	select f.fact_numero, f.fact_sucursal, f.fact_tipo
	from Factura f
	where f.fact_cliente in (select clie_codigo from deleted)

	declare @item_numero char(8)
	declare @item_tipo char(1)
	declare @item_suc char(4)

	open aBorrar
	fetch aBorrar into @item_numero, @item_suc, @item_tipo

	while @@FETCH_STATUS = 0
	begin
		print concat(@item_numero,'-->',@item_numero)
		delete from	Item_Factura
		where item_numero = @item_numero and item_sucursal = @item_suc and item_tipo = @item_tipo

		delete from Factura
		where fact_numero = @item_numero and fact_sucursal = @item_suc and fact_tipo = @item_tipo

		fetch aBorrar
		into @item_numero, @item_suc, @item_tipo
	end	

	close aBorrar
	deallocate aBorrar
	
	delete cliente where clie_codigo in (select clie_codigo from deleted)

commit

--verificaciones para testear el trigger
select distinct fact_cliente from Factura where fact_cliente in ('02269','03652')
delete from Cliente where clie_codigo in ('02269','03652')
select * from Cliente where clie_codigo in ('02269','03652')

--importante!!
drop trigger ej_trigger_cliente
--hay que correr el drop para borrar el trgiger de instead of, ya que solo puede haer un instead of por tabla, en cambio un trigger after puede haber varios
--pero el trgiger instead of solo uno. sino te va a tirar error cuando trate de crear otro.


--otra forma de resolverlo (forma del profe)
create trigger ej_trigger_cliente
on cliente
instead of delete
as
begin transaction
	delete from item_factura
	where exists (select 1 from factura, deleted
					where item_numero = fact_numero and
					item_tipo = fact_tipo and item_sucursal = fact_sucursal
					and fact_cliente = clie_codigo)
	delete from factura
	where exists (select 1 from deleted where fact_cliente = clie_codigo)
	delete from Cliente
	where clie_codigo in (select clie_codigo from deleted)
commit



/*
26. (no es de la guia, por lo menos de la nueva) desarrolle el/los objetos de base de datos necesarios para que se cumpla
automaticamente la regla de que una factura(item_factura) NO puede contener productos que sean componentes de otros productos.
En caso de que esto ocurra NO debe grabarse esa factura y debe emitirse un error en pantalla.
*/

create trigger control_factura on item_factura after update, insert as --creo que para el insert podes usar el instead of pero para el update solo el after
begin
	begin transaction
		declare @cant_productos_prohibidos decimal(12,2)
		select @cant_productos_prohibidos = count(1) from inserted join Composicion on item_producto = comp_componente

		if (@cant_productos_prohibidos > 0)
		begin
			insert into Item_Factura select * from inserted
		end
		else
		begin
			rollback
			print 'no se pueden facturar productos que sean componentes de otros productos'
			return -- el return es importantisimo ponerlo luego de un rollback , porque sino no te corta el ciclo de ejecucion y cuando vaya al commit te tira error
		end
	commit
end

create trigger control_composicion on Composicion after update, insert as
begin
	begin transaction
		declare @cant_composicion_prohibido decimal(12,2)
		select @cant_composicion_prohibido = count(1) from inserted join Item_Factura on comp_componente = item_producto

		if (@cant_composicion_prohibido > 0) 
		begin 
			insert into Composicion select * from inserted
		end
		else
		begin
			rollback
			print 'no se pueden facturar productos que sean componentes de otros productos'
			return -- el return es importantisimo ponerlo luego de un rollback , porque sino no te corta el ciclo de ejecucion y cuando vaya al commit te tira error
		end
	commit
end











 









































